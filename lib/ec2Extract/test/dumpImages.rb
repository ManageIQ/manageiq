require 'rubygems'
require 'aws-sdk'
require_relative '../credentials'

begin

	ec2 = AWS::EC2.new(:access_key_id => AMAZON_ACCESS_KEY_ID, :secret_access_key => AMAZON_SECRET_ACCESS_KEY)

	images = ec2.images.with_owner('self')

	icount = 0

	puts "EC2 Images:"
	images.each do |ami|
		icount += 1
		puts "\tEC2 Image (#{icount}) ================="
		puts "\t\tImage name:       #{ami.name}"
		puts "\t\tImage location:   #{ami.location}"
		puts "\t\tImage Type:       #{ami.type}"
		puts "\t\tImage ID:         #{ami.id}"
		puts "\t\tArchitecture:     #{ami.architecture}"
		puts "\t\tPlatform:         #{ami.platform}"
		puts "\t\tState:            #{ami.state}"
		puts "\t\tState reason:     #{ami.state_reason}"
		puts "\t\tRoot device name: #{ami.root_device_name}"
		puts "\t\tRoot device type: #{ami.root_device_type}"
		puts "\t\tBlock device mappings:"
		ami.block_device_mappings.each do |k, v|
			puts "\t\t\t#{k}:"
			v.each do |vk, vv|
				puts "\t\t\t\t#{vk}:\t#{vv}"
			end
		end
		puts
	end

rescue => err
	puts err.to_s
	puts err.backtrace.join("\n")
end
