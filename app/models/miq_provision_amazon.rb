class MiqProvisionAmazon < MiqProvisionCloud
  include_concern 'Cloning'
  include_concern 'StateMachine'
  include_concern 'Configuration'
end
