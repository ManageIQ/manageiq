require 'pp'
require '../Ec2InstanceMetadata'
require '../Ec2Payload'

begin
	eim = Ec2InstanceMetadata.new
	rawUd = eim.user_data
	
	puts
	puts rawUd
	puts
	
	yamlStr = Ec2Payload.decode(rawUd)

	puts
	pp yamlStr
	
rescue => err
	puts err.to_s
	puts err.backtrace.join("\n")
end
