#
# Description: This method attempts to retire all of the vms under this top level service
#

$evm.log("info", "Listing Root Object Attributes:")
$evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
$evm.log("info", "===========================================")

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

service.vms.each  do |vm|
  $evm.log('info', "Would call vm retirement for vm: #{vm.inspect}")
  $evm.root['vm'] = vm
  $evm.root['vm_id'] = vm.id
  $evm.log("info", "Listing Root Object Attributes:")
  $evm.root.attributes.sort.each { |k, v| $evm.log("info", "#{@method} - \t#{k}: #{v}")}
  $evm.log("info", "===========================================")
  # $evm.instantiate("/Automation/VMLifecycle/Retirement")
end
