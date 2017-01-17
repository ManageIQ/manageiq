class ManageIQ::Providers::Redhat::InfraManager::Provision < MiqProvision
  include_concern 'Cloning'
  include_concern 'Configuration'
  include_concern 'Placement'
  include_concern 'StateMachine'
  include_concern 'Disk'

  def destination_type
    "Vm"
  end

  def get_provider_destination
    return nil if destination.nil?
    destination.with_provider_object { |rhevm_vm| return rhevm_vm }
  end
end
