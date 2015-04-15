class MiqProvisionMicrosoft < MiqProvision
  include_concern 'Cloning'
  include_concern 'Placement'
  include_concern 'StateMachine'
end

# Preload any subclasses of this class, so that they will be part of the
#   conditions that are generated on queries against this class.
Dir.glob(Rails.root.join("app", "models", "miq_provision_microsoft_*.rb")).each { |f| require_dependency f }
