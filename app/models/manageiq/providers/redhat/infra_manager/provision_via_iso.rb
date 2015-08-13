class ManageIQ::Providers::Redhat::InfraManager::ProvisionViaIso < ManageIQ::Providers::Redhat::InfraManager::Provision
  include_concern 'Cloning'
  include_concern 'StateMachine'
end
