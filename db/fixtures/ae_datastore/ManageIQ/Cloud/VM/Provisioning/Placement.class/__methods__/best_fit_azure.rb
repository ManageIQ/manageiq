###################################################################
#
# Description: Select the cloud network and availability zone for Azure
#
###################################################################

$evm.log("info", "Using Auto Placement for Azure Cloud Provider")
prov  = $evm.root["miq_provision"]
image = prov.vm_template
raise "Image not specified" if image.nil?

if prov.get_option(:cloud_network).nil?
  cloud_network = prov.eligible_cloud_networks.first

  if cloud_network
    prov.set_cloud_network(cloud_network)
    $evm.log("info", "Selected Cloud Network: #{cloud_network.name}")
  end
end

if prov.get_option(:cloud_subnet).nil?
  cloud_subnet = prov.eligible_cloud_subnets.first

  if cloud_subnet
    prov.set_cloud_subnet(cloud_subnet)
    $evm.log("info", "Selected Cloud Subnet: #{cloud_subnet.name}")
  end
end

if prov.get_option(:resource_group).nil?
  resource_group = prov.eligible_resource_groups.first

  if resource_group
    prov.set_resource_group(resource_group)
    $evm.log("info", "Selected Resource Group: #{resource_group.name}")
  end
end
