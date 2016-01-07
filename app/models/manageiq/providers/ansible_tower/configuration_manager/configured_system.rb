class ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfiguredSystem < ::ConfiguredSystem
  include ProviderObjectMixin

  def provider_object(connection = nil)
    (connection || connection_source.connect).host(manager_ref)
  end

  def ext_management_system
    configuration_manager
  end

  private

  def connection_source(options = {})
    options[:connection_source] || configuration_manager
  end
end
