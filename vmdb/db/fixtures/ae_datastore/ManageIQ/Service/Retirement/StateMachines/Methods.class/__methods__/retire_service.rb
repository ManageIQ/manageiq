#
# Description: This method attempts to retire all of the vms under this top level service
#

$evm.log("info", "#{@method} - Listing Root Object Attributes:") 
$evm.root.attributes.sort.each { |k, v| $evm.log("info", "#{@method} - \t#{k}: #{v}")  }
$evm.log("info", "#{@method} - ===========================================") 
$evm.root["service"].retire_service_resources
