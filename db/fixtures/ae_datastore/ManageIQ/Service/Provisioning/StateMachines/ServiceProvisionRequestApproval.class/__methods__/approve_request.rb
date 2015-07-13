#
# Description: This method is executed when the provisioning request is auto-approved
#

# Auto-Approve request
$evm.log("info", "Checking for auto_approval")
approval_type = $evm.object['approval_type'].downcase
if approval_type == 'auto'
  $evm.log("info", "AUTO-APPROVING")
  $evm.root["miq_request"].approve("admin", "Auto-Approved")
end
