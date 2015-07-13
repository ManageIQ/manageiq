#
# Description: This method marks the service as retired
#

service = $evm.root['service']
if service.nil?
  $evm.log('info', "Service Object not found")
  exit MIQ_ABORT
end

unless service.parent_service.nil?
  $evm.log('info', "Cannot continue, Not the top level service.  Parent_service: #{service.parent_service}")
  exit MIQ_ABORT
end

$evm.log('info', "Service before: #{service.inspect} marked as retired.")

service.retire_now
$evm.log('info', "Service: #{service.inspect} marked as retired.")
