#
# Description: This method launches the service provisioning job
#

$evm.log("info", "Listing Root Object Attributes:")
$evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
$evm.log("info", "===========================================")

$evm.root["service_template_provision_task"].execute
