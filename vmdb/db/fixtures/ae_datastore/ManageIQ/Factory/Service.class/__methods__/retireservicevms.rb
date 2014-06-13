###################################
#
# EVM Automate Method: retireservicemethods
#
# Notes: This method attempts to retire all of the vms under this top level service
#
###################################
begin
  @method = 'retireservicevms'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  $evm.log("info", "#{@method} - Listing Root Object Attributes:") if @debug
  $evm.root.attributes.sort.each { |k, v| $evm.log("info", "#{@method} - \t#{k}: #{v}") if @debug }
  $evm.log("info", "#{@method} - ===========================================") if @debug

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

  service.vms.each  do |v|
    $evm.log('info', "#{@method} - ZZZZZZZ Would call vm retirement for vm: #{v.inspect}")
    $evm.root['vm'] = v
    $evm.root['vm_id'] = v.id
    $evm.log("info", "#{@method} - AGAIN Listing Root Object Attributes:") if @debug
    $evm.root.attributes.sort.each { |k, v| $evm.log("info", "#{@method} - \t#{k}: #{v}") if @debug }
    $evm.log("info", "#{@method} - ===========================================") if @debug
    # $evm.instantiate("/Automation/VMLifecycle/Retirement")
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
