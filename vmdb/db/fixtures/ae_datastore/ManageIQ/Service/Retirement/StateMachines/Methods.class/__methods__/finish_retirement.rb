#
# Description: This method marks the service as retired
#

$evm.log("info", "Listing Root Object Attributes:")
$evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}")  }
$evm.log("info", "===========================================")

service = $evm.root['service']
$evm.root["service"].finish_retirement if service
