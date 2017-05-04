module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::TowerApi
  extend ActiveSupport::Concern

  module ClassMethods
    def create_in_provider(manager_id, params)
      params = provider_params(params) if respond_to?(:provider_params)
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
      notify('creation', manager.id, params, error.nil?)
    end

    def create_in_provider_queue(manager_id, params)
      manager = ExtManagementSystem.find(manager_id)
      action = "Creating #{self::FRIENDLY_NAME} (name=#{params[:name]})"
      queue(manager.my_zone, nil, "create_in_provider", [manager_id, params], action)
    end

    private
    def notify(op, manager_id, params, success)
      params = hide_secrets(params) if respond_to?(:hide_secrets)
      _log.info "#{name} in_provider #{op} with parameters: #{params} #{success ? 'succeeded' : 'failed'}"
      op_arg = params.each_with_object([]) { |(k, v), l| l.push("#{k}=#{v}") if [:name, :manager_ref].include?(k) }.join(', ')
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

    def queue(zone, instance_id, method_name, args, action)
      task_opts = {
        :action => action,
        :userid => "system"
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
    params.delete(:task_id) # in case this is being called through update_in_provider_queue which will stick in a :task_id
    params = self.class.provider_params(params) if self.class.respond_to?(:provider_params)
    with_provider_object do |provider_object|
      provider_object.update_attributes!(params)
    end
    self.class.send('refresh', self)
    reload
  rescue AnsibleTowerClient::ClientError => error
    raise
  ensure
    self.class.send('notify', 'update', manager.id, params, error.nil?)
  end

  def update_in_provider_queue(params)
    action = "Updating #{self.class::FRIENDLY_NAME} (Tower internal reference=#{manager_ref})"
    self.class.send('queue', manager.my_zone, id, "update_in_provider", [params], action)
  end

  def delete_in_provider
    with_provider_object(&:destroy!)
    self.class.send('refresh', manager)
  rescue AnsibleTowerClient::ClientError => error
    raise
  ensure
    self.class.send('notify', 'deletion', manager.id, {:manager_ref => manager_ref}, error.nil?)
  end

  def delete_in_provider_queue
    action = "Deleting #{self.class::FRIENDLY_NAME} (Tower internal reference=#{manager_ref})"
    self.class.send('queue', manager.my_zone, id, "delete_in_provider", [], action)
  end
end
