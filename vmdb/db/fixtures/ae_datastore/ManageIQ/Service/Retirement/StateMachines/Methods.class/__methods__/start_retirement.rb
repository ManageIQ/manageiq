#
# Description: This method sets the retirement_state to retiring
#

$evm.log("info", "Listing Root Object Attributes:") 
$evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}")  }
$evm.log("info", "===========================================") 

service = $evm.root['service']
if service.nil?
  $evm.log('info', "Service Object not found") 
  exit MIQ_ABORT
end

$evm.log('info', "Service before start_retirement: #{service.inspect} ")

if service.is_or_being_retired? 
  $evm.log('info', "Service is already retired, or is in the process of being retired. Aborting current State Machine.") 
  exit MIQ_ABORT
end
  
service.start_retirement

$evm.log('info', "Service after start_retirement: #{service.inspect} ")
