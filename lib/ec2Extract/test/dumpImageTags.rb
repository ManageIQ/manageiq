require 'rubygems'
require 'aws-sdk'
require_relative '../credentials'

begin
	ec2 = AWS::EC2.new(:access_key_id => AMAZON_ACCESS_KEY_ID, :secret_access_key => AMAZON_SECRET_ACCESS_KEY)

	puts "EC2 Images with tags:"
	ec2.images.each_with_index do |ami, icount|
		next if ami.tags.empty?
		
		puts "\tEC2 Image (#{icount + 1}) ================="
		puts "\t\tImage location: #{ami.location}"
		puts "\t\tTags:"
		ami.tags.each { |k, v| puts "\t\t\t#{k}\t=>#{v}"}
		puts
	end
rescue => err
	puts err.to_s
	puts err.backtrace.join("\n")
end
