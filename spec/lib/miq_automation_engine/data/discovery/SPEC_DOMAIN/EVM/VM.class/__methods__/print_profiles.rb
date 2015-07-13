disc = $evm.object.children('get_profiles')
$evm.log("info", "Discovery Results: [#{disc['name']}] - #{disc['profile_name'].inspect}")
