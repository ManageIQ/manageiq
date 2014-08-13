#
# Description: This method is used to apply PreProvision customizations for Openstack provisioning
#

# Get provisioning object
prov = $evm.root['miq_provision']

$evm.log("info", "Provisioning ID:<#{prov.id}> Provision Request ID:<#{prov.miq_provision_request.id}> Provision Type: <#{prov.provision_type}>")
