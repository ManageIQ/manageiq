###################################
#
# EVM Automate Method: delete_from_vc_check
#
# Notes: This method checks to see if the VM has been deleted from the VC
#
###################################
begin
  @method = 'delete_from_vc_check'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  vm = $evm.root['vm']

  category = "lifecycle"
  tag = "retire_full"

  miq_guid = /\w*MIQ\sGUID/i
  if vm.v_annotation =~  miq_guid
    vm_was_provisioned = true
  else
    vm_was_provisioned = false
  end

  if vm && (vm_was_provisioned || vm.miq_provision || vm.tagged_with?(category, tag))
    host = vm.host
    $evm.log('info', "#{@method} - VM <#{vm.name}> parent Host ID is <#{host}>")
    if host.nil?
      # Bump State
      $evm.root['ae_result'] = 'ok'
    else
      $evm.root['ae_result']         = 'retry'
      $evm.root['ae_retry_interval'] = '15.seconds'
    end
  else
    # Bump State
    $evm.root['ae_result'] = 'ok'
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
  exit MIQ_ABORT
end
