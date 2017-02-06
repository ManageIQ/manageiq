class ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScriptSource
  module ApiCreate
    def create_in_provider(manager_id, params)
      manager = ExtManagementSystem.find(manager_id)
      project = manager.with_provider_connection do |connection|
        connection.api.projects.create!(params)
      end

      # Get the record in our database
      # TODO: This needs to be targeted refresh so it doesn't take too long
      EmsRefresh.queue_refresh(manager, nil, true) if !manager.missing_credentials? && manager.authentication_status_ok?

      find_by(:manager_id => manager.id, :manager_ref => project.id)
    end

    def create_in_provider_queue(manager_id, params)
      task_opts = {
        :action => "Creating Ansible Tower Project",
        :userid => "system"
      }

      manager = ExtManagementSystem.find(manager_id)

      queue_opts = {
        :args        => [manager_id, params],
        :class_name  => "ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScriptSource",
        :method_name => "create_in_provider",
        :priority    => MiqQueue::HIGH_PRIORITY,
        :role        => "ems_operations",
        :zone        => manager.my_zone
      }

      MiqTask.generic_action_with_callback(task_opts, queue_opts)
    end
  end
end
