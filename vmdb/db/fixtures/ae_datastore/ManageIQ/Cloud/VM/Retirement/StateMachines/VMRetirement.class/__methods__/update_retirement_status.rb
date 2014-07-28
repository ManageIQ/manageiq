###################################
#
# EVM Automate Method: update_retirement_status
#
# Notes: This method updates retirement status
#
# Required inputs: status
#
###################################
begin
  @method = 'update_retirement_status'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  # Get vm from root
  vm = $evm.root['vm']

  # Get variables from Server object
  server = $evm.root['miq_server']

  # Get State Machine
  state = $evm.current_object.class_name

  # Get current step
  step = $evm.current_object.current_field_name

  # Get status from input field status
  status = $evm.inputs['status']

  # Get status_state ['on_entry', 'on_exit', 'on_error']
  status_state = $evm.root['ae_status_state']

  $evm.log("info", "#{@method} - Server:<#{server.name}> Ae_Result:<#{$evm.root['ae_result']}> State:<#{state}> Step:<#{step}> Status_State:<#{status_state}> Status:<#{status}>")

  ###################################
  #
  # Update Status for on_entry,on_exit
  #
  ###################################
  if $evm.root['ae_result'] == 'ok'

  end

  ###################################
  #
  # Update Status for on_error
  #
  ###################################
  if $evm.root['ae_result'] == 'error'

  end

  #
  # Exit method
  #
  $evm.log("info", "#{@method} - EVM Automate Method Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "#{@method} - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_STOP
end
