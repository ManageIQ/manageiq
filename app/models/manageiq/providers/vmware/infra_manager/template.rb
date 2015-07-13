class ManageIQ::Providers::Vmware::InfraManager::Template < ManageIQ::Providers::InfraManager::Template
  include_concern 'ManageIQ::Providers::Vmware::InfraManager::VmOrTemplateShared'

  def cloneable?
    true
  end
end
