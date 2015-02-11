#
# Description: This method checks to see that all of the service resources are retired before retiring the service.
#

$evm.log("info", "Listing Root Object Attributes:")
$evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}")  }
$evm.log("info", "===========================================")

service = $evm.root['service']
if service.nil?
  $evm.log('info', "Service Object not found")
  exit MIQ_ABORT
end

$evm.log('info', "Checking if all service resources have been retired.")

result = 'ok'

unretired_obj = service.service_resources.detect do |sr|
  sr.resource &&
  sr.resource.respond_to?(:retired?) &&
  !sr.resource.retired?
end

if unretired_obj
  result = 'retry'
  $evm.log('info', "resource: #{unretired_obj.resource.name} is not retired, setting retry.")
end

$evm.log('info', "Service: #{service.name} Resource retirement check returned <#{result}>")
case result
when 'retry'
  $evm.log('info', "Service: #{service.name} resource is not retired, setting retry.")
  $evm.root['ae_result']         = 'retry'
  $evm.root['ae_retry_interval'] = '1.minute'
when 'ok'
  # Bump State
  $evm.log('info', "All resources are retired for service: #{service.name}. ")
  $evm.root['ae_result'] = 'ok'
end
