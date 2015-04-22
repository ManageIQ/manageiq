class MiqProvisionRedhat < MiqProvision
  include_concern 'Cloning'
  include_concern 'Configuration'
  include_concern 'Placement'
  include_concern 'StateMachine'

  def destination_type
    "Vm"
  end

  def get_provider_destination
    return nil if self.destination.nil?
    self.destination.with_provider_object { |rhevm_vm| return rhevm_vm }
  end
end
