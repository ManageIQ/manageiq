require 'rubygems'
require 'aws-sdk'
require_relative '../credentials'

begin

	ec2 = AWS::EC2.new(:access_key_id => AMAZON_ACCESS_KEY_ID, :secret_access_key => AMAZON_SECRET_ACCESS_KEY)

	key_pairs = ec2.key_pairs

	puts "EC2 key pairs:"
	key_pairs.each do |kp|
		puts "\t#{kp.name}\t#{kp.fingerprint}"
	end

rescue => err
	puts err.to_s
	puts err.backtrace.join("\n")
end
