class ManageIQ::Providers::Oracle::InfraManager::Template < ManageIQ::Providers::InfraManager::Template
  include_concern 'ManageIQ::Providers::Oracle::InfraManager::VmOrTemplateShared'
end
