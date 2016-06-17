class ManageIQ::Providers::Azure::CloudManager::Provision < ManageIQ::Providers::CloudManager::Provision
  include_concern 'Cloning'
  include_concern 'OptionsHelper'
  include_concern 'StateMachine'
end
