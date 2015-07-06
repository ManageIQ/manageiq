require 'soap/wsdlDriver'

token = ENV['MIQ_TOKEN']
driver = SOAP::WSDLDriverFactory.new("http://localhost:3000/vmdbws/wsdl").create_rpc_driver
ws = "EVMSet"
puts "Calling WS [#{ws}]..."
result = driver.send(ws, token, "#tester", "Oleg Barenboim")
puts "WS call completed, result=#{result}"

exit MIQ_OK
