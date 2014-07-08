###################################
#
# Description: select the first provider.availability_zone.
#
###################################

# Get variables
prov     = $evm.root["miq_provision"]
template = prov.vm_template
raise "Template not specified" if template.nil?
provider = template.ext_management_system
raise "Provider not found for template [#{template.name}" if provider.nil?

availability_zones = provider.availability_zones
current_obj = $evm.current
current_obj["availability_zone"] = availability_zones.first

$evm.log("info", "Template=[#{template.name}]  AvailabilityZone=[#{current_obj["availability_zone"]}]")
