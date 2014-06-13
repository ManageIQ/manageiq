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

# Preload any subclasses of this class, so that they will be part of the
#   conditions that are generated on queries against this class.
Dir.glob(Rails.root.join("app", "models", "miq_provision_redhat_*.rb")).each { |f| require_dependency f }
