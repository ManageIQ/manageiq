service = $evm.root['service']
if service.nil?
  $evm.log('error', 'get_retirement_entrypoint: missing service object')
  exit MIQ_ABORT
end

entry_point = service.automate_retirement_entrypoint
if entry_point.blank?
  entry_point = '/Service/Retirement/StateMachines/ServiceRetirement/Default'
  $evm.log("info", "retirement_entrypoint not specified using default: #{entry_point}")
end

$evm.root['retirement_entry_point']	= entry_point
$evm.log("info", "retirement_entrypoint: #{entry_point}")
