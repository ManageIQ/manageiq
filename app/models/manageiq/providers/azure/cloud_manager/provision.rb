class ManageIQ::Providers::Azure::CloudManager::Provision < ManageIQ::Providers::CloudManager::Provision
  include_concern 'Cloning'
  include_concern 'Configuration'
  include_concern 'OptionsHelper'
end
