#
# Description: This method is executed when the provisioning request is auto-approved
#

# Auto-Approve request
$evm.log("info", "AUTO-APPROVING")
$evm.root["miq_request"].approve("admin", "Auto-Approved")
