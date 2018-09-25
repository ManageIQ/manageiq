module ProcessTasksMixin
  extend ActiveSupport::Concern
  include RetirementMixin

  module ClassMethods
    # Processes tasks received from the UI and queues them
    def process_tasks(options)
      raise _("No ids given to process_tasks") if options[:ids].blank?
      if options[:task] == 'retire_now'
        name.constantize.make_retire_request(*options[:ids])
      elsif options[:task] == "refresh_ems" && respond_to?("refresh_ems")
        refresh_ems(options[:ids])
        msg = "'#{options[:task]}' initiated for #{options[:ids].length} #{ui_lookup(:table => base_class.name).pluralize}"
        task_audit_event(:success, options, :message => msg)
      else
        assert_known_task(options)
        options[:userid] ||= User.current_user.try(:userid) || "system"
        invoke_tasks_queue(options)
      end
    end

    def invoke_tasks_queue(options)
      q_hash = {
        :class_name  => name,
        :method_name => "invoke_tasks",
        :args        => [options]
      }
      user = User.current_user
      q_hash.merge!(:user_id => user.id, :group_id => user.current_group.id, :tenant_id => user.current_tenant.id) if user
      MiqQueue.submit_job(q_hash)
    end

    # Performs tasks received from the UI via the queue
    def invoke_tasks(options)
      local, remote = partition_ids_by_remote_region(options[:ids])

      invoke_tasks_local(options.merge(:ids => local)) if local.present?
      invoke_tasks_remote(options.merge(:ids => remote)) if remote.present?
    end

    def invoke_tasks_local(options)
      options[:invoke_by] = task_invoked_by(options)
      args = task_arguments(options)

      instances, tasks = validate_tasks(options)

      instances.zip(tasks) do |instance, task|
        if task && task.status == "Error"
          task_audit_event(:failure, options, :target_id => instance.id, :message => task.message)
          task.state_finished
          next
        end

        invoke_task_local(task, instance, options, args)

        msg = "#{instance.name}: '#{options[:task]}' initiated"
        msg = "[Name: #{instance.name},Id: #{instance.id}, Ems_ref: #{instance.ems_ref}] Record destroyed" if options[:task] == 'destroy'

        task_audit_event(:success, options, :target_id => instance.id, :message => msg)
        task.update_status("Queued", "Ok", "Task has been queued") if task
      end
    end

    def invoke_tasks_remote(options)
      ApplicationRecord.group_ids_by_region(options[:ids]).each do |region, ids|
        remote_options = options.merge(:ids => ids)

        begin
          remote_connection = InterRegionApiMethodRelay.api_client_connection_for_region(region, remote_options[:userid])
          invoke_api_tasks(remote_connection, remote_options)
        rescue NotImplementedError => err
          $log.error("#{name} is not currently able to invoke tasks for remote regions")
          $log.log_backtrace(err)
          next
        rescue => err
          # Handle specific error case, until we can figure out how it occurs
          if err.class == ArgumentError && err.message == "cannot interpret as DNS name: nil"
            $log.error("An error occurred while invoking remote tasks...")
            $log.log_backtrace(err)
            next
          end

          $log.error("An error occurred while invoking remote tasks...Requeueing for 1 minute from now.")
          $log.log_backtrace(err)

          q_hash = {
            :class_name  => name,
            :method_name => 'invoke_tasks_remote',
            :args        => [remote_options],
            :deliver_on  => Time.now.utc + 1.minute
          }
          user = User.current_user
          q_hash.merge!(:user_id => user.id, :group_id => user.current_group.id, :tenant_id => user.current_tenant.id) if user
          MiqQueue.submit_job(q_hash)
          next
        end

        msg = "'#{options[:task]}' successfully initiated for remote VMs: #{ids.sort.inspect}"
        task_audit_event(:success, options, :message => msg)
      end
    end

    # Override as needed to handle differences between API actions and method names
    def action_for_task(task)
      task
    end

    def invoke_api_tasks(api_client, remote_options)
      collection_name = Api::CollectionConfig.new.name_for_klass(self)
      unless collection_name
        _log.error("No API entpoint found for class #{name}")
        raise NotImplementedError
      end

      collection   = api_client.send(collection_name)
      action       = action_for_task(remote_options[:task])
      post_args    = remote_options[:args] || {}
      resource_ids = remote_options[:ids]

      if resource_ids.present?
        resource_ids.each do |id|
          begin
            obj = collection.find(id)
          rescue ManageIQ::API::Client::ResourceNotFound => err
            _log.error(err.message)
          else
            _log.info("Invoking task #{action} on collection #{collection_name}, object #{obj.id}, with args #{post_args}")
            begin
              obj.send(action, post_args)
            rescue NoMethodError => err
              _log.error(err.message)
            end
          end
        end
      else
        _log.info("Invoking task #{action} on collection #{collection_name}, with args #{post_args}")
        begin
          collection.send(action, post_args)
        rescue NoMethodError => err
          _log.error(err.message)
        end
      end
    end

    # default: invoked by task, can be overridden
    def task_invoked_by(_options)
      :task
    end
    private :task_invoked_by

    # default: only handles retirement, can be overridden
    def task_arguments(options)
      options[:task] == 'retire_now' ? [options[:userid]] : []
    end
    private :task_arguments

    # default implementation, can be overridden
    def invoke_task_local(task, instance, options, args)
      cb = {
        :class_name  => task.class.to_s,
        :instance_id => task.id,
        :method_name => :queue_callback,
        :args        => ["Finished"]
      } if task

      q_hash = {
        :class_name   => name,
        :instance_id  => instance.id,
        :method_name  => options[:task],
        :args         => args,
        :miq_callback => cb
      }
      user = User.current_user
      q_hash.merge!(:user_id => user.id, :group_id => user.current_group.id, :tenant_id => user.current_tenant.id) if user
      MiqQueue.submit_job(q_hash)
    end

    private

    # Helper method for invoke_tasks, to determine the instances and the tasks associated
    def validate_tasks(options)
      tasks = []

      instances = base_class.where(:id => options[:ids]).order("lower(name)").to_a
      return instances, tasks unless options[:invoke_by] == :task # jobs will be used instead of tasks for feedback

      instances.each do |instance|
        # create a task for each instance
        task = MiqTask.create(:name => "#{instance.name}: '#{options[:task]}'", :userid => options[:userid])
        tasks.push(task)

        validate_task(task, instance, options)
      end
      return instances, tasks
    end

    # default: validate retirement, can be overridden
    def validate_task(task, instance, options)
      return true unless options[:task] == "retire_now" && instance.retired?
      task.error("#{instance.name} is already retired")
      false
    end

    def task_audit_event(event, task_options, audit_options)
      options =
        {
          :event        => task_options[:task],
          :target_class => base_class.name,
          :userid       => task_options[:userid],
        }.merge(audit_options)
      AuditEvent.send(event, options)
    end

    def assert_known_task(options)
      unless instance_methods.collect(&:to_s).include?(options[:task])
        raise _("Unknown task, %{task}") % {:task => options[:task]}
      end
    end
  end
end
