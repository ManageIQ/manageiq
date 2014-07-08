#
# Description: This method auto-approves the vm migration request
#

$evm.log("info", "AUTO-APPROVING")
$evm.root["miq_request"].approve("admin", "Auto-Approved")
