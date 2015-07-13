class MiqProvisionMicrosoft < MiqProvision
  include_concern 'Cloning'
  include_concern 'Placement'
  include_concern 'StateMachine'
end
