class MiqProvisionTaskConfiguredSystemForeman < MiqProvisionTask
  include_concern 'OperationsHelper'
  include_concern 'OptionsHelper'
  include_concern 'StateMachine'

  def model_class
    ConfiguredSystemForeman
  end
end
