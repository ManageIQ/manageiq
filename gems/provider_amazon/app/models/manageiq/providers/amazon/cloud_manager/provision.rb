class ManageIQ::Providers::Amazon::CloudManager::Provision < ManageIQ::Providers::CloudManager::Provision
  include_concern 'Cloning'
  include_concern 'StateMachine'
  include_concern 'Configuration'
end
