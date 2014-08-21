###################################################################
#
# Description: select the cloud network
#              Default availability zone is provided by Openstack
#
###################################################################

# Get variables
prov     = $evm.root["miq_provision"]
image    = prov.vm_template
raise "Image not specified" if image.nil?

if prov.get_option(:cloud_network).nil?
  cloud_network = prov.eligible_cloud_networks.first
  if cloud_network
    prov.set_cloud_network(cloud_network)
    $evm.log("info", "Image=[#{image.name}] Cloud Network=[#{cloud_network.name}]")
  end
end
