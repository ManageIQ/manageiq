#
# Description: This method checks to see that all of the vms are retired before retiring the service.
#

$evm.log("info", "Listing Root Object Attributes:")
$evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
$evm.log("info", "===========================================")

# Get current provisioning status
service = $evm.root['service']
if service.nil?
  $evm.log('info', "Service Object not found")
  exit MIQ_ABORT
end

$evm.log('info', "Service inspect: #{service.inspect} ")

unless service.parent_service.nil?
  $evm.log('info', "Cannot continue, Not the top level service.  Parent_service: #{service.parent_service}")
  exit MIQ_ABORT
end

result = 'ok'
vm_name = nil

unretired_obj = service.vms.detect { |v| !v.retired }
if unretired_obj
  result = 'retry'
  vm_name = v.name
  $evm.log('info', "vm: #{v.name} is not retired, setting retry.")
end

$evm.log('info', "Service: #{service.name} VM retirement check returned <#{result}>")

case result
when 'error'
  $evm.log('info', "Service: #{service.name}. Not all VMs are retired. can not proceed with retirement.")
  $evm.root['ae_result'] = 'error'
  reason = $evm.root['service_template_provision_task'].message
  reason = reason[7..-1] if reason[0..6] == 'Error: '
  $evm.root['ae_reason'] = reason
when 'retry'
  $evm.log('info', "Service: #{service.name} VM: #{vm_name} is not retired, setting retry.")
  $evm.root['ae_result']         = 'retry'
  $evm.root['ae_retry_interval'] = '1.minute'
when 'ok'
  # Bump State
  $evm.log('info', "All VMs are retired for service: #{service.name}. ")
  $evm.root['ae_result'] = 'ok'
end
