#
# Description: This method marks the VM as retired
#

vm = $evm.root['vm']
$evm.root["vm"].finish_retirement if vm
