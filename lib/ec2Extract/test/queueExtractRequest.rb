#!/usr/bin/env ruby

$:.push("#{File.dirname(__FILE__)}/..")

require 'rubygems'
require 'log4r'
require_relative '../credentials'
require_relative '../Ec2ExtractQueue'
require_relative '../tools/ExtractUserData'

class ConsoleFormatter < Log4r::Formatter
	def format(event)
		(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end
$log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::OFF, :formatter=>ConsoleFormatter)
$log.add 'err_console'

begin

	userData = ExtractUserData::user_data
	
	AWS.config(:access_key_id => AMAZON_ACCESS_KEY_ID, :secret_access_key => AMAZON_SECRET_ACCESS_KEY)
	eeq = Ec2ExtractQueue.new(userData)
	
	# ami-edad1984	AMI (EBS)
	# i-06359e7c	Instance (EBS)
	# ami-20e90e49	AMI (instance_store)
	# i-07f1b47c	Instance (instance_store)
	[ 'ami-edad1984', 'i-06359e7c', 'ami-20e90e49', 'i-07f1b47c' ].each do |ec2_id|
	# [ 'i-07f1b47c' ].each do |ec2_id|
		msg = eeq.send_extract_request(ec2_id)
		puts "Sent message for #{ec2_id}: #{msg.id}"
	end
		
rescue => err
	puts err.to_s
	puts err.backtrace.join("\n")
end
