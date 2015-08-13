class ManageIQ::Providers::Redhat::InfraManager::ProvisionViaPxe < ManageIQ::Providers::Redhat::InfraManager::Provision
  include_concern 'Cloning'
  include_concern 'StateMachine'
end
