#
# Description: Quota Exceeded rejected method.
#

request = $evm.root["miq_request"]
$evm.log('info', "Request denied because of #{request.message}")
request.deny("admin", "Quota Exceeded")

$evm.create_notification(:level => "error", :subject => request, \
                         :message => "Quota Exceeded: #{request.message}")
