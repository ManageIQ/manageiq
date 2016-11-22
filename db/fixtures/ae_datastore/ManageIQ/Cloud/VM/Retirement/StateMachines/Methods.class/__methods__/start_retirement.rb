#
# Description: This method sets the retirement_state to retiring
#

$evm.log("info", "Listing Root Object Attributes:")
$evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
$evm.log("info", "===========================================")

vm = $evm.root['vm']
if vm.nil?
  $evm.log('error', "VM Object not found")
  exit MIQ_ABORT
end

if vm.retired?
  $evm.log('error', "VM is already retired. Aborting current State Machine.")
  exit MIQ_ABORT
end

if vm.retiring?
  $evm.log('error', "VM is in the process of being retired. Aborting current State Machine.")
  exit MIQ_ABORT
end

$evm.log('info', "VM before start_retirement: #{vm.inspect} ")
$evm.create_notification(:type => :vm_retiring, :subject => vm)

vm.start_retirement

$evm.log('info', "VM after start_retirement: #{vm.inspect} ")
