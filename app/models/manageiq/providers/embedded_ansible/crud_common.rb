module ManageIQ::Providers::EmbeddedAnsible::CrudCommon
  extend ActiveSupport::Concern

  module ClassMethods
    def queue(instance_id, method_name, args, action, auth_user)
      task_opts = {
        :action => action,
        :userid => auth_user || "system"
      }

      queue_opts = {
        :args        => args,
        :priority    => MiqQueue::HIGH_PRIORITY,
        :class_name  => name,
        :method_name => method_name,
        :role        => "embedded_ansible",
        :zone        => nil
      }
      queue_opts[:instance_id] = instance_id if instance_id
      MiqTask.generic_action_with_callback(task_opts, queue_opts)
    end

    def notify(op_type, manager_id, params)
      error = nil
      yield
    rescue StandardError => error
      _log.debug(error.result.error) if error.kind_of?(AwesomeSpawn::CommandResultError)
      raise
    ensure
      send_notification(op_type, manager_id, params, error.nil?) if notify_on_provider_interaction?
    end

    def notify_on_provider_interaction?
      false
    end

    def raw_create_in_provider(_manager, _params)
      raise NotImplementedError, "must be implemented in a subclass"
    end

    def create_in_provider(manager_id, params)
      manager = ExtManagementSystem.find(manager_id)
      notify('creation', manager_id, params) do
        raw_create_in_provider(manager, params)
      end
    end

    def encrypt_queue_params(params)
      params
    end

    def create_in_provider_queue(manager_id, params, auth_user = nil)
      manager = parent.find(manager_id)
      action = "Creating #{self::FRIENDLY_NAME}"
      action << " (name=#{params[:name]})" if params[:name]
      queue(nil, "create_in_provider", [manager_id, encrypt_queue_params(params)], action, auth_user)
    end

    private

    def send_notification(op_type, manager_id, params, success)
      op_arg = params.except(*notification_excludes).collect { |k, v| "#{k}=#{v}" }.join(', ')
      _log.send(success ? :info : :error, "#{name} #{op_type} with parameters: #{op_arg.inspect} #{success ? 'succeeded' : 'failed'}")
      Notification.create!(
        :type    => success ? :tower_op_success : :tower_op_failure,
        :options => {
          :op_name => "#{self::FRIENDLY_NAME} #{op_type}",
          :op_arg  => "(#{op_arg})",
          :tower   => "EMS(manager_id=#{manager_id})"
        }
      )
    end

    # Override in subclass if necessary
    def notification_excludes
      [:name, :manager_ref] + Authentication.encrypted_columns
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

  def encrypt_queue_params(params)
    self.class.encrypt_queue_params(params)
  end

  def update_in_provider_queue(params, auth_user = nil)
    queue("update_in_provider", [encrypt_queue_params(params)], "Updating", auth_user)
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
    self.class.queue(id, method_name, args, action, auth_user)
  end

  def notify(op_type, params = {}, &block)
    self.class.notify(op_type, manager_id, params, &block)
  end
end
