#
# Description: This default method is used to apply PreProvision provisioning customizations.
#

# Get provisioning object
prov = $evm.root["miq_provision"]
$evm.log("info", "Provision:<#{prov.id}> Request:<#{prov.miq_provision_request.id}> Type:<#{prov.type}>")
