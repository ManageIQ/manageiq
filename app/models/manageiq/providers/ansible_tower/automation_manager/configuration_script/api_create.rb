class ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript
  module ApiCreate
    def create_in_provider(manager_id, params)
      manager = ExtManagementSystem.find(manager_id)
      job_template = manager.with_provider_connection do |connection|
        connection.api.job_templates.create!(params)
      end

      # Get the record in our database
      # TODO: This needs to be targeted refresh so it doesn't take too long
      EmsRefresh.queue_refresh(manager, nil, true) if !manager.missing_credentials? && manager.authentication_status_ok?

      find_by(:manager_id => manager.id, :manager_ref => job_template.id)
    end
  end
end
