require 'rubygems'
require 'aws-sdk'
require_relative '../credentials'

begin
	ec2 = AWS::EC2.new(:access_key_id => AMAZON_ACCESS_KEY_ID, :secret_access_key => AMAZON_SECRET_ACCESS_KEY)

	puts "EC2 Instances:"
	ec2.instances.each_with_index do |ami, icount|
		puts "\tEC2 Instance (#{icount + 1}) ================="
		puts "\t\tInstance ID:    #{ami.id}"
		puts "\t\tImage ID:       #{ami.image_id}"
		puts "\t\tArchitecture:   #{ami.architecture}"
		puts "\t\tKey name:       #{ami.key_name}"
		puts "\t\tStatus:         #{ami.status}"
		puts "\t\tRoot dev name:  #{ami.root_device_name}"
		puts "\t\tRoot dev type:  #{ami.root_device_type}"
		puts "\t\tBlock device mappings:"
		ami.block_device_mappings.each do |k, v|
			puts "\t\t\t#{k}:"
			puts "\t\t\t\tdevice:\t#{v.device}"
			puts "\t\t\t\tinstance:\t#{v.instance.id}"
			puts "\t\t\t\tvolume:\t#{v.volume.id}"
			puts "\t\t\t\tstatus:\t#{v.status}"
		end
		puts
	end

rescue => err
	puts err.to_s
	puts err.backtrace.join("\n")
end
