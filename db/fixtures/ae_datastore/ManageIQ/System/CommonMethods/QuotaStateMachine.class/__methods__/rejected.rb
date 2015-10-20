#
# Description: <Method description here>
#

$evm.log('info', "Request denied because of Quota")
$evm.root["miq_request"].deny("admin", "Quota Exceeded")
