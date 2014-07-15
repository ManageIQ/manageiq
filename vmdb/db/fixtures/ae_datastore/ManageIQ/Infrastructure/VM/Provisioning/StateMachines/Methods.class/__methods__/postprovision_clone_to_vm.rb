#
# Description: This method is used to customize the provisioning object prior to provisioning
#

# Get Variables
prov = $evm.root["miq_provision"]
$evm.log("info", "Inspecting Provisioning Object: #{prov.inspect}")

# Get Provision Type
prov_type = prov.provision_type
$evm.log("info", "Provision Type: <#{prov_type}>")

# Get template
template = prov.vm_template
$evm.log("info", "Inspecting Template Object: #{template.inspect}")

tags = template.tags
$evm.log("info", "Inspecting Template Tags: #{tags.inspect}")

