###################################
#
# EVM Automate Method: markserviceasretired
#
# Notes: This method marks the service as retired
#
###################################
begin
  @method = 'markserviceasretired'
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

  $evm.log('info', "#{@method} - Service before: #{service.inspect} marked as retired.")

  service.retire_now
  $evm.log('info', "#{@method} - Service: #{service.inspect} marked as retired.")

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
