#
# Description: This method is used to apply PreProvision customizations during the cloning to a VM:
#

# Get provisioning object
prov = $evm.root["miq_provision"]

$evm.log("info", "Provisioning ID:<#{prov.id}> Provision Request ID:<#{prov.miq_provision_request.id}> Provision Type: <#{prov.provision_type}>")
