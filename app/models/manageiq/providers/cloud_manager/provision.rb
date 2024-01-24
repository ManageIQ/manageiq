class ManageIQ::Providers::CloudManager::Provision < MiqProvision
  include Cloning
  include OptionsHelper
  include Placement
  include StateMachine
  include Configuration
  include VolumeAttachment

  def destination_type
    "Vm"
  end
end
