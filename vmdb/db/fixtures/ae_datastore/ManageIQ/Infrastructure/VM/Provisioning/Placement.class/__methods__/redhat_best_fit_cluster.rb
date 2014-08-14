#
# Description: This method sets the cluster based on source template
#

# Get variables
prov = $evm.root["miq_provision"]
vm = prov.vm_template
raise "VM not specified" if vm.nil?
user = prov.miq_request.requester
raise "User not specified" if user.nil?
ems  = vm.ext_management_system
raise "EMS not found for VM [#{vm.name}" if ems.nil?

$evm.log("info", "vm=[#{vm.name}]")

cluster = vm.ems_cluster
$evm.log("info", "Selected Cluster: [#{cluster.nil? ? "nil" : cluster.name}]")

# Set cluster
prov.set_cluster(cluster) if cluster

$evm.log("info", "vm=[#{vm.name}] cluster=[#{cluster}]")
