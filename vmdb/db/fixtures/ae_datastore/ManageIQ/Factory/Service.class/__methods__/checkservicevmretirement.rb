###################################
#
# EVM Automate Method: checkservicevmretirement
#
# Notes: This method checks to see that all of the vms are retired before retiring the service.
#
###################################
begin
  @method = 'checkservicevmretirement'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  $evm.log("info", "#{@method} - Listing Root Object Attributes:") if @debug
  $evm.root.attributes.sort.each { |k, v| $evm.log("info", "#{@method} - \t#{k}: #{v}") if @debug }
  $evm.log("info", "#{@method} - ===========================================") if @debug

  # Get current provisioning status
  service = $evm.root['service']
  if service.nil?
    $evm.log('info', "#{@method} - Service Object not found")
    exit MIQ_ABORT
  end

  $evm.log('info', "#{@method} - Service inspect: #{service.inspect} ")

  unless service.parent_service.nil?
    $evm.log('info', "#{@method} - Cannot continue, Not the top level service.  Parent_service: #{service.parent_service}")
    exit MIQ_ABORT
  end

  result = 'ok'
  vm_name = nil

  service.vms.each do |v|
    $evm.log('info', "#{@method} - checking if vm: #{v.name} is retired.")
    unless v.retired
      result = 'retry'
      vm_name = v.name
      # $evm.log('info', "#{@method} - Checking if vm: #{v.name}" is retired.")
      $evm.log('info', "#{@method} - vm: #{v.name} is not retired, setting retry.")
      break
    end
  end

  $evm.log('info', "#{@method} - Service: #{service.name} VM retirement check returned <#{result}>") if @debug

  case result
  when 'error'
    $evm.log('info', "#{@method} - Service: #{service.name}. Not all VMs are retired. can not proceed with retirement.")
    $evm.root['ae_result'] = 'error'
    reason = $evm.root['service_template_provision_task'].message
    reason = reason[7..-1] if reason[0..6] == 'Error: '
    $evm.root['ae_reason'] = reason
  when 'retry'
    $evm.log('info', "#{@method} - Service: #{service.name} VM: #{vm_name} is not retired, setting retry.")
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '1.minute'
  when 'ok'
    # Bump State
    $evm.log('info', "#{@method} - All VMs are retired for service: #{service.name}. ")
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
