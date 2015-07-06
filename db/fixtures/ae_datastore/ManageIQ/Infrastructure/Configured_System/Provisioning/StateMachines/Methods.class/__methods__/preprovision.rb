#
# Description: This method is used to apply PreProvision customizations
#

# Get provisioning object
prov = $evm.root['miq_provision_task']

$evm.log("info", "Provisioning ID:<#{prov.id}> Provision Request ID:<#{prov.miq_request.id}> Provision Type: <#{prov.request_type}>")
