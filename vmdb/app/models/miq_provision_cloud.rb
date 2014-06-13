class MiqProvisionCloud < MiqProvision

  SUBCLASSES = %w{
    MiqProvisionAmazon
    MiqProvisionOpenstack
  }

  include_concern 'Cloning'
  include_concern 'OptionsHelper'
  include_concern 'Placement'
  include_concern 'StateMachine'
  include_concern 'Configuration'

  def destination_type
    "Vm"
  end
end

# Preload any subclasses of this class, so that they will be part of the
#   conditions that are generated on queries against this class.
MiqProvisionCloud::SUBCLASSES.each { |c| require_dependency Rails.root.join("app", "models", "#{c.underscore}.rb").to_s }
