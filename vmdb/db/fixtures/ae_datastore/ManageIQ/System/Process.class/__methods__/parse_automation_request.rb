###################################
#
# EVM Automate Method: parse_automation_request
#
# Notes: This method is used to parse incoming automation requests
#
###################################
begin
  @method = 'parse_automation_request'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  cur = $evm.object
  case cur['request']
  when 'vm_provision'
    cur['target_class']    = 'VMLifecycle'
    cur['target_instance'] = 'Provisioning'
  when 'vm_retired'
    cur['target_class']    = 'VMLifecycle'
    cur['target_instance'] = 'Retirement'
  when 'vm_migrate'
    cur['target_class']    = 'VMLifecycle'
    cur['target_instance'] = 'Migrate'
  when 'host_provision'
    cur['target_class']    = 'HostLifecycle'
    cur['target_instance'] = 'Provisioning'
  end

  $evm.log("info", "#{@method} - Request:<#{cur['request']}> Target Class:<#{cur['target_class']}> Target Instance:<#{cur['target_instance']}>") if @debug

  #
  # Exit method
  #
  $evm.log("info", "#{@method} - EVM Automate Method Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "<#{@method}>: [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
