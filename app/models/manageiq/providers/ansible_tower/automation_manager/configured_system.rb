class ManageIQ::Providers::AnsibleTower::AutomationManager::ConfiguredSystem < ::ConfiguredSystem
  include ProviderObjectMixin

  def provider_object(connection = nil)
    (connection || connection_source.connect).api.hosts.find(manager_ref)
  end

  def ext_management_system
    manager
  end

  private

  def connection_source(options = {})
    options[:connection_source] || manager
  end
end
