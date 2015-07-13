$evm.log("info", "===========================================")
$evm.log("info", "Dumping Object")

$evm.log("info", "Args:    #{MIQ_ARGS.inspect}")
$evm.log("info", "Message: #{MIQ_MESSAGE}")

obj = $evm.object
$evm.log("info", "Listing Object Attributes:")
obj.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
$evm.log("info", "===========================================")

exit MIQ_OK
