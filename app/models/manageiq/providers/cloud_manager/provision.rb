class ManageIQ::Providers::CloudManager::Provision < MiqProvision
  include_concern 'Cloning'
  include_concern 'OptionsHelper'
  include_concern 'Placement'
  include_concern 'StateMachine'
  include_concern 'Configuration'
  include_concern 'VolumeAttachment'

  def destination_type
    "Vm"
  end
end
