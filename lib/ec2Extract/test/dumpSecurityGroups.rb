require 'rubygems'
require 'aws-sdk'
require_relative '../credentials'

begin

	ec2 = AWS::EC2.new(:access_key_id => AMAZON_ACCESS_KEY_ID, :secret_access_key => AMAZON_SECRET_ACCESS_KEY)

	security_groups = ec2.security_groups

	puts "Security groups:"
	security_groups.each do |sg|
		puts "\t#{sg.name}\t#{sg.description}"
	end

rescue => err
	puts err.to_s
	puts err.backtrace.join("\n")
end
