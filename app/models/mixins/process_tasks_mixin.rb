module ProcessTasksMixin
  extend ActiveSupport::Concern

  module ClassMethods
    # Processes tasks received from the UI and queues them
    def process_tasks(options)
      raise _("No ids given to process_tasks") if options[:ids].blank?
      if options[:task] == "refresh_ems" && respond_to?("refresh_ems")
        refresh_ems(options[:ids])
        msg = "'#{options[:task]}' initiated for #{options[:ids].length} #{ui_lookup(:table => base_class.name).pluralize}"
        task_audit_event(:success, options, :message => msg)
      else
        assert_known_task(options)
        options[:userid] ||= "system"
        invoke_tasks_queue(options)
      end
    end

    def invoke_tasks_queue(options)
      MiqQueue.put(:class_name => name, :method_name => "invoke_tasks", :args => [options])
    end

    # Performs tasks received from the UI via the queue
    def invoke_tasks(options)
      local, remote = partition_ids_by_remote_region(options[:ids])
      invoke_tasks_local(options.merge(:ids => local)) unless local.empty?

      # TODO: invoke_tasks_remote currently is only implemented by VmOrTemplate.
      # it can be refactored to be generalized like invoke_tasks_local
      invoke_tasks_remote(options.merge(:ids => remote)) if remote.present? && respond_to?("invoke_tasks_remote")
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
        task_audit_event(:success, options, :target_id => instance.id, :message => msg)
        task.update_status("Queued", "Ok", "Task has been queued") if task
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

      MiqQueue.put(
        :class_name   => name,
        :instance_id  => instance.id,
        :method_name  => options[:task],
        :args         => args,
        :miq_callback => cb
      )
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
