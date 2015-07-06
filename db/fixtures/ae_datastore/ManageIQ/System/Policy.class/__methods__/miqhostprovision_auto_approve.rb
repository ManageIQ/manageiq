#
# Description: This method auto-approves the host provisioning request
#
$evm.log("info", "AUTO-APPROVING")
$evm.root["miq_request"].approve("admin", "Auto-Approved")
