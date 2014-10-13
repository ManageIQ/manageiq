#
# Description: This method marks the VM as retired
#

$evm.log("info", "Listing Root Object Attributes:") 
$evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}")  }
$evm.log("info", "===========================================") 

vm = $evm.root['vm']
if vm.nil?
  $evm.log('info', "VM Object not found") 
  exit MIQ_ABORT
end

$evm.log('info', "VM before finish_retirement: #{vm.inspect} ")

$evm.root["vm"].finish_retirement

$evm.log('info', "VM after finish_retirement: #{vm.inspect} ")

