#
# Description: This method auto-approves the VM Reconfiguration request
#
$evm.log("info", "AUTO-APPROVING")
$evm.root["miq_request"].approve("admin", "VM Reconfiguration Auto-Approved")
