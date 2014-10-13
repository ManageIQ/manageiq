###################################
# EVM Automate Method: finish_retirement
# Notes: This method marks the service as retired
###################################
@method = 'finish_retirement'
$evm.log("info", "#{@method} - EVM Automate Method Started")

$evm.log("info", "#{@method} - Listing Root Object Attributes:") 
$evm.root.attributes.sort.each { |k, v| $evm.log("info", "#{@method} - \t#{k}: #{v}")  }
$evm.log("info", "#{@method} - ===========================================") 

service = $evm.root['service']
if service.nil?
  $evm.log('info', "#{@method} - Service Object not found") 
  exit MIQ_ABORT
end

$evm.root["service"].finish_retirement

$evm.log("info", "#{@method} - EVM Automate Method Ended")
exit MIQ_OK
