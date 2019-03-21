module ManageIQ::Providers::EmbeddedAnsible::CrudCommon
  extend ActiveSupport::Concern

  module ClassMethods
    def queue(zone, instance_id, method_name, args, action, auth_user)
      task_opts = {
        :action => action,
        :userid => auth_user || "system"
      }

      queue_opts = {
        :args        => args,
        :class_name  => name,
        :method_name => method_name,
        :role        => "ems_operations",  # TODO: This should go to a git_owner
        :zone        => zone
      }
      queue_opts[:instance_id] = instance_id if instance_id
      MiqTask.generic_action_with_callback(task_opts, queue_opts)
    end

    def notify(op, manager_id, params)
      error = nil
      yield
    rescue => error
      _log.debug error.result.error if error.is_a?(AwesomeSpawn::CommandResultError)
      raise
    ensure
      send_notification(op, manager_id, params, error.nil?) if notify_on_provider_interaction?
    end

    def notify_on_provider_interaction?
      false
    end

    private def send_notification(op, manager_id, params, success)
      op_arg = params.except(:name, :manager_ref).collect { |k, v| "#{k}=#{v}" }.join(', ')
      _log.send(success ? :info : :error, "#{name} #{op} with parameters: #{op_arg.inspect} #{success ? 'succeeded' : 'failed'}")
      Notification.create!(
        :type    => success ? :tower_op_success : :tower_op_failure,
        :options => {
          :op_name => "#{self::FRIENDLY_NAME} #{op}",
          :op_arg  => "(#{op_arg})",
          :tower   => "EMS(manager_id=#{manager_id})"
        }
      )
    end

    def raw_create_in_provider(manager, params)
      raise NotImplementedError, "must be implemented in a subclass"
    end

    def create_in_provider(manager_id, params)
      manager = ExtManagementSystem.find(manager_id)
      notify('creation', manager_id, params) do
        raw_create_in_provider(manager, params)
      end
    end

    def create_in_provider_queue(manager_id, params, auth_user = nil)
      manager = parent.find(manager_id)
      action = "Creating #{self::FRIENDLY_NAME}"
      action << " (name=#{params[:name]})" if params[:name]
      queue(manager.my_zone, nil, "create_in_provider", [manager_id, params], action, auth_user)
    end
  end

  def raw_update_in_provider
    raise NotImplementedError, "must be implemented in a subclass"
  end

  def update_in_provider(params)
    notify('update', params) do
      raw_update_in_provider(params)
    end
    self
  end

  def update_in_provider_queue(params, auth_user = nil)
    queue("update_in_provider", [params], "Updating", auth_user)
  end

  def raw_delete_in_provider
    raise NotImplementedError, "must be implemented in a subclass"
  end

  def delete_in_provider
    notify('deletion') do
      raw_delete_in_provider
    end
    self
  end

  def delete_in_provider_queue(auth_user = nil)
    queue("delete_in_provider", [], "Deleting", auth_user)
  end

  private

  def queue(method_name, args, action_prefix, auth_user)
    action = "#{action_prefix} #{self.class::FRIENDLY_NAME}"
    action << " (name=#{name})" if respond_to?(:name)
    self.class.queue(manager.my_zone, id, method_name, args, action, auth_user)
  end

  def notify(op, params = {}, &block)
    self.class.notify(op, manager_id, params, &block)
  end
end
