#
# Description: This method is used to process tasks immediately after the VM has been provisioned
#

# Get Variables
prov = $evm.root["miq_provision"]
$evm.log("info", "Provisioning ID:<#{prov.id}> Provision Request ID:<#{prov.miq_provision_request.id}>")

# Get provisioned VM from prov object
vm = prov.vm
unless vm.nil?
  $evm.log("info", "VM:<#{vm.name}> has been provisioned")
end
