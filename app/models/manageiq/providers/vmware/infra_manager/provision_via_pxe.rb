class ManageIQ::Providers::Vmware::InfraManager::ProvisionViaPxe < ManageIQ::Providers::Vmware::InfraManager::Provision
  include_concern 'Cloning'
  include_concern 'Pxe'
  include_concern 'StateMachine'
end
