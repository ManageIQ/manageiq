#
# Description: This method runs when the service request quota validation has failed
#

quota_reason = $evm.object['reason'] || "Quota Exceeded"
$evm.log(:info, "#{quota_reason}")
$evm.root["miq_request"].deny("admin", quota_reason)
