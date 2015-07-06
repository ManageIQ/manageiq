$evm.log("info", "===========================================")
$evm.log("info", "Dumping Object")

$evm.log("info", "Args:    #{MIQ_ARGS.inspect}")

obj = $evm.object
$evm.log("info", "Listing Object Attributes:")
obj.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
$evm.log("info", "===========================================")

require 'soap/wsdlDriver'

token = ENV['MIQ_TOKEN']
driver = SOAP::WSDLDriverFactory.new("http://localhost:3000/vmdbws/wsdl").create_rpc_driver
ws = "EVMGet"
puts "Calling WS [#{ws}]..."
result = driver.send(ws, token, "#tester")
puts "WS call completed, result=#{result}"

ws = "EVMSet"
puts "Calling WS [#{ws}]..."
result = driver.send(ws, token, "#tester", "Oleg Barenboim")
puts "WS call completed, result=#{result}"

ws = "EVMGet"
puts "Calling WS [#{ws}]..."
result = driver.send(ws, token, "#tester")
puts "WS call completed, result=#{result}"

exit MIQ_OK
