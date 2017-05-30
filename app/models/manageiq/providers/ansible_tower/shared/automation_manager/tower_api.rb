module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::TowerApi
  extend ActiveSupport::Concern

  module ClassMethods
    def create_in_provider(manager_id, params)
      params = provider_params(params) if respond_to?(:provider_params)
      process_secrets(params, true) if respond_to?(:process_secrets)
      manager = ExtManagementSystem.find(manager_id)
      tower_object = provider_collection(manager).create!(params)
      if respond_to?(:refresh_in_provider)
        refresh_in_provider(tower_object)
      end
      refresh(manager)
      find_by!(:manager_id => manager.id, :manager_ref => tower_object.id)
    rescue AnsibleTowerClient::ClientError, ActiveRecord::RecordNotFound => error
      raise
    ensure
      notify('creation', manager.id, params, error.nil?) if try(:notify_on_provider_interaction?)
    end

    def create_in_provider_queue(manager_id, params, auth_user = nil)
      process_secrets(params) if respond_to?(:process_secrets)
      manager = ExtManagementSystem.find(manager_id)
      action = "Creating #{self::FRIENDLY_NAME} (name=#{params[:name]})"
      queue(manager.my_zone, nil, "create_in_provider", [manager_id, params], action, auth_user)
    end

    private

    def notify(op, manager_id, params, success)
      op_arg = params.each_with_object([]) { |(k, v), l| l.push("#{k}=#{v}") if [:name, :manager_ref].include?(k) }.join(', ')
      _log.info "#{name} in_provider #{op} with parameters: #{op_arg} #{success ? 'succeeded' : 'failed'}"
      Notification.create(
        :type    => success ? :tower_op_success : :tower_op_failure,
        :options => {
          :op_name => "#{self::FRIENDLY_NAME} #{op}",
          :op_arg  => "(#{op_arg})",
          :tower   => "Tower(manager_id=#{manager_id})"
        }
      )
    end

    def refresh(target)
      # Get the record into our database
      task_ids = EmsRefresh.queue_refresh_task(target)
      task_ids.each { |tid| MiqTask.wait_for_taskid(tid) }
    end

    def queue(zone, instance_id, method_name, args, action, auth_user)
      task_opts = {
        :action => action,
        :userid => auth_user || "system"
      }

      queue_opts = {
        :args        => args,
        :class_name  => name,
        :method_name => method_name,
        :priority    => MiqQueue::HIGH_PRIORITY,
        :role        => "ems_operations",
        :zone        => zone
      }
      queue_opts[:instance_id] = instance_id if instance_id
      MiqTask.generic_action_with_callback(task_opts, queue_opts)
    end
  end

  def update_in_provider(params)
    self.class.process_secrets(params, true) if self.class.respond_to?(:process_secrets)
    params.delete(:task_id) # in case this is being called through update_in_provider_queue which will stick in a :task_id
    params = self.class.provider_params(params) if self.class.respond_to?(:provider_params)
    with_provider_object do |provider_object|
      provider_object.update_attributes!(params)
    end
    if respond_to?(:refresh_in_provider)
      refresh_in_provider
    end
    self.class.send('refresh', manager)
    reload
  rescue AnsibleTowerClient::ClientError => error
    raise
  ensure
    if self.class.try(:notify_on_provider_interaction?)
      self.class.send('notify', 'update', manager.id, params, error.nil?)
    end
  end

  def update_in_provider_queue(params, auth_user = nil)
    self.class.process_secrets(params) if self.class.respond_to?(:process_secrets)
    action = "Updating #{self.class::FRIENDLY_NAME} (Tower internal reference=#{manager_ref})"
    self.class.send('queue', manager.my_zone, id, "update_in_provider", [params], action, auth_user)
  end

  def delete_in_provider
    with_provider_object(&:destroy!)
    self.class.send('refresh', manager)
  rescue AnsibleTowerClient::ClientError => error
    raise
  ensure
    if self.class.try(:notify_on_provider_interaction?)
      self.class.send('notify', 'deletion', manager.id, {:manager_ref => manager_ref}, error.nil?)
    end
  end

  def delete_in_provider_queue(auth_user = nil)
    action = "Deleting #{self.class::FRIENDLY_NAME} (Tower internal reference=#{manager_ref})"
    self.class.send('queue', manager.my_zone, id, "delete_in_provider", [], action, auth_user)
  end
end
