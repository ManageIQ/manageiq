class ManageIQ::Providers::Redhat::InfraManager::Template < ManageIQ::Providers::InfraManager::Template
  include_concern 'ManageIQ::Providers::Redhat::InfraManager::VmOrTemplateShared'

  def self.supports_kickstart_provisioning?
    true
  end

  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.get_resource_by_ems_ref(ems_ref)
  end
end
