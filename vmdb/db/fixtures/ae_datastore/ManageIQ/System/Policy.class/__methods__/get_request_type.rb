###################################
#
# EVM Automate Method: get_request_type
#
# Notes: This method is used get the incoming request type
#
###################################
begin
  @method = 'get_request_type'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  miq_request = $evm.root["miq_request"]
  raise "#{@method} - MiqRequest Not Found" if miq_request.nil?

  $evm.object['request_type'] = miq_request.resource_type
  $evm.root['user'] ||= $evm.root['miq_request'].requester

  $evm.log("info", "#{@method} - Request Type:<#{$evm.object['request_type']}>") if @debug

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
