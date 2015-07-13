#
# Description: This method is used get the incoming request type
#

miq_request = $evm.root["miq_request"]
raise "MiqRequest Not Found" if miq_request.nil?

$evm.object['request_type'] = miq_request.resource_type
$evm.root['user'] ||= $evm.root['miq_request'].requester

$evm.log("info", "Request Type:<#{$evm.object['request_type']}>")
