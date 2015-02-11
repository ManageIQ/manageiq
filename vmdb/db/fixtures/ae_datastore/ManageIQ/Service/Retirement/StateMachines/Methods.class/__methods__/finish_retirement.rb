#
# Description: This method marks the service as retired.
#

$evm.log("info", "Listing Root Object Attributes:")
$evm.root.attributes.sort.each { |k, v| $evm.log("info", " \t#{k}: #{v}")  }
$evm.log("info", "===========================================")

service = $evm.root['service']
if service.nil?
  $evm.log('info', "Service Object not found")
  exit MIQ_ABORT
end

$evm.root["service"].finish_retirement
