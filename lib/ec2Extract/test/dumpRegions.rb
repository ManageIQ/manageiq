require 'rubygems'
require 'aws-sdk'
require_relative '../credentials'

begin
	ec2 = AWS::EC2.new(:access_key_id => AMAZON_ACCESS_KEY_ID, :secret_access_key => AMAZON_SECRET_ACCESS_KEY)

	puts "Regions:"
	ec2.regions.each do |r|
		puts "\t#{r.name}\t#{r.endpoint} (available: #{r.exists?})"
		puts "\t\tImages:    #{r.images.with_owner('self').count}"
		puts "\t\tInstances: #{r.instances.count}"
		availability_zones = r.availability_zones
		puts "\t\tAvailability zones:"
		availability_zones.each do |az|
			puts "\t\t\t#{az.name}\t(state: #{az.state})"
		end
		puts
	end
rescue => err
	puts err.to_s
	puts err.backtrace.join("\n")
end
