class ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfiguredSystem < ::ConfiguredSystem
  include ProviderObjectMixin

  belongs_to :manager,
             :class_name  => 'ConfigurationManager',
             :foreign_key => 'configuration_manager_id'

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
