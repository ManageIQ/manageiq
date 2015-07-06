obj = $evm.object("process")
$evm.log("info", "VM Discovery for #{obj['name']} State: #{obj['vm_state']} Family: #{obj['vm_os_family']}")
