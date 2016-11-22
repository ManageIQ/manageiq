#
# Description: This method sets the retirement_state to retiring
#

service = $evm.root['service']
if service.nil?
  $evm.log('error', "Service Object not found")
  exit MIQ_ABORT
end

$evm.log('info', "Service before start_retirement: #{service.inspect} ")

if service.retired?
  $evm.log('error', "Service is already retired. Aborting current State Machine.")
  exit MIQ_ABORT
end

if service.retiring?
  $evm.log('error', "Service is in the process of being retired. Aborting current State Machine.")
  exit MIQ_ABORT
end

$evm.create_notification(:type => :service_retiring, :subject => service)
service.start_retirement

$evm.log('info', "Service after start_retirement: #{service.inspect} ")
