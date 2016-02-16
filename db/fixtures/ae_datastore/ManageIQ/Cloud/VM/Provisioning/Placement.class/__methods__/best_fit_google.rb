###################################################################
#
# Description: Select the cloud network and availability zone for Google
#
###################################################################

prov  = $evm.root["miq_provision"]
image = prov.vm_template
raise "Image not specified" if image.nil?

if prov.get_option(:availability_zone).nil?
  availability_zone = prov.eligible_availability_zones.first

  if availability_zone
    prov.set_availability_zone(availability_zone)
    $evm.log("info", "Image=[#{image.name}] Availability Zone=[#{availability_zone.name}]")
  end
end

if prov.get_option(:cloud_network).nil?
  cloud_network = prov.eligible_cloud_networks.first

  if cloud_network
    prov.set_cloud_network(cloud_network)
    $evm.log("info", "Image=[#{image.name}] Cloud Network=[#{cloud_network.name}]")
  end
end
