###################################
#
# EVM Automate Method: update_serviceprovision_status
#
# Notes: This method updates the service provisioning status
#
# Required inputs: status, status_state
#
###################################
begin
  @method = 'update_serviceprovision_status'
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Started")

  $evm.log("info", "===========================================")
  $evm.log("info", "Listing ROOT Attributes:")
  $evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
  $evm.log("info", "===========================================")

  prov    = $evm.root['service_template_provision_task']

  # Get provisioning type [template, clone_to_vm or clone_to_template]
  prov_type = prov.request_type

  # Get State Machine
  state = $evm.current_object.class_name

  # Get current step
  step = $evm.current_object.current_field_name

  # Get status from input field status
  status = $evm.inputs['status']

  # Get status_state ['on_entry', 'on_exit', 'on_error'] from input field
  status_state = $evm.inputs['status_state']

  ###################################
  #
  # Update Status for on_entry,on_exit
  #
  ###################################
  if $evm.root['ae_result'] == 'ok'

    # Check to see if provisioning is complete
    if status == 'provision_complete'
      message      = 'Service Provisioned Successfully'
      prov.finished(message)
    end
    prov.message = status
  end

  ###################################
  #
  # Update Status for on_error
  #
  ###################################
  if $evm.root['ae_result'] == 'error'
    prov.message = status
  end

  #
  # Exit method
  #
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "<#{@method}>: [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_STOP
end
