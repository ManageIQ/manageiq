module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::ConfigurationScriptSource
  extend ActiveSupport::Concern

  include ProviderObjectMixin

  module ClassMethods
    def provider_collection(manager)
      manager.with_provider_connection do |connection|
        connection.api.projects
      end
    end
  end

  def provider_object(connection = nil)
    (connection || connection_source.connect).api.projects.find(manager_ref)
  end
end
