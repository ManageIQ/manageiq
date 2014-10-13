#
# Description: This method attempts to retire all of the vms under this top level service
#

$evm.log("info", "Listing Root Object Attributes:") 
$evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}")  }
$evm.log("info", "===========================================") 
$evm.root["service"].retire_service_resources
