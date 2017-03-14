module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::Credential
  extend ActiveSupport::Concern

  module ClassMethods
    def create_in_provider(manager_id, params)
      manager = ExtManagementSystem.find(manager_id)
      credential = manager.with_provider_connection do |connection|
        connection.api.credentials.create!(params)
      end

      refresh(manager)
      find_by!(:resource_id => manager.id, :manager_ref => credential.id)
    end

    def create_in_provider_queue(manager_id, params)
      manager = ExtManagementSystem.find(manager_id)
      action = "Creating #{name} with name=#{params[:name]}"
      queue(manager.my_zone, nil, "create_in_provider", [manager_id, params], action)
    end

    private

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
    resource.with_provider_connection do |connection|
      connection.api.credentials.find(manager_ref).update_attributes!(params)
    end
    self.class.send('refresh', resource)
    reload
  end

  def update_in_provider_queue(params)
    action = "Updating #{self.class.name} with manager_ref=#{manager_ref}"
    self.class.send('queue', resource.my_zone, id, "update_in_provider", [params], action)
  end

  def delete_in_provider
    resource.with_provider_connection do |connection|
      connection.api.credentials.find(manager_ref).destroy!
    end
    self.class.send('refresh', resource)
  end

  def delete_in_provider_queue
    action = "Deleting #{self.class.name} with manager_ref=#{manager_ref}"
    self.class.send('queue', resource.my_zone, id, "delete_in_provider", [], action)
  end
end
