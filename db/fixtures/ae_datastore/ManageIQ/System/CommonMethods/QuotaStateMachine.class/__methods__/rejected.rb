#
# Description: <Method description here>
#

$evm.log('info', "Request denied because of #{$evm.root["miq_request"].message}")
$evm.root["miq_request"].deny("admin", "Quota Exceeded")
