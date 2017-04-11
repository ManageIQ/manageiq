module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::TowerApi
  extend ActiveSupport::Concern

  module ClassMethods
    def create_in_provider(manager_id, params)
      params = provider_params(params) if respond_to?(:provider_params)
      manager = ExtManagementSystem.find(manager_id)
      tower_object = provider_collection(manager).create!(params)

      refresh(manager)
      find_by!(:manager_id => manager.id, :manager_ref => tower_object.id)
    rescue AnsibleTowerClient::ClientError, ActiveRecord::RecordNotFound => error
      raise
    ensure
      notify('create_in_provider', manager.id, params, error.nil?)
    end

    def create_in_provider_queue(manager_id, params)
      manager = ExtManagementSystem.find(manager_id)
      action = "Creating #{name} with name=#{params[:name]}"
      queue(manager.my_zone, nil, "create_in_provider", [manager_id, params], action)
    end

    private
    def notify(op, manager_id, params, success)
      params = hide_secrets(params) if respond_to?(:hide_secrets)
      Notification.create(
        :type    => success ? :tower_op_success : :tower_op_failure,
        :options => {
          :op_name => "#{name.demodulize} #{op}",
          :op_arg  => params.to_s,
          :tower   => "Tower(manager_id: #{manager_id})"
        }
      )
    end

    def refresh(manager)
      # Get the record in our database
      # TODO: This needs to be targeted refresh so it doesn't take too long
      task_ids = EmsRefresh.queue_refresh_task(manager)
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
    self.class.send('refresh', manager)
    reload
  rescue AnsibleTowerClient::ClientError => error
    raise
  ensure
    self.class.send('notify', 'update_in_provider', manager.id, params, error.nil?)
  end

  def update_in_provider_queue(params)
    action = "Updating #{self.class.name} with Tower internal reference=#{manager_ref}"
    self.class.send('queue', manager.my_zone, id, "update_in_provider", [params], action)
  end

  def delete_in_provider
    with_provider_object(&:destroy!)
    self.class.send('refresh', manager)
  rescue AnsibleTowerClient::ClientError => error
    raise
  ensure
    self.class.send('notify', 'delete_in_provider', manager.id, {:manager_ref => manager_ref}, error.nil?)
  end

  def delete_in_provider_queue
    action = "Deleting #{self.class.name} with Tower internal reference=#{manager_ref}"
    self.class.send('queue', manager.my_zone, id, "delete_in_provider", [], action)
  end
end
