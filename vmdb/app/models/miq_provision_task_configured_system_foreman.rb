class MiqProvisionTaskConfiguredSystemForeman < MiqProvisionTask
  include_concern 'OperationsHelper'
  include_concern 'StateMachine'
end
