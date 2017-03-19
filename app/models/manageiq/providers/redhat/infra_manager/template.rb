class ManageIQ::Providers::Redhat::InfraManager::Template < ManageIQ::Providers::InfraManager::Template
  include_concern 'ManageIQ::Providers::Redhat::InfraManager::VmOrTemplateShared'

  supports :provisioning do
    if ext_management_system
      unsupported_reason_add(:provisioning, ext_management_system.unsupported_reason(:provisioning)) unless ext_management_system.supports_provisioning?
    else
      unsupported_reason_add(:provisioning, _('not connected to ems'))
    end
  end

  def self.supports_kickstart_provisioning?
    true
  end

  def provider_object(connection = nil)
    ovirt_services_class = ManageIQ::Providers::Redhat::InfraManager::OvirtServices::Builder
                           .build_from_ems_or_connection(:ems => ext_management_system, :connection => connection)
    ovirt_services_class.new(:ems => ext_management_system).get_template_proxy(self, connection)
  end
end
