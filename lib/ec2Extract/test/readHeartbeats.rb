#!/usr/bin/env ruby

require 'rubygems'
require 'log4r'

require_relative '../tools/ExtractUserData'
require_relative '../Ec2ExtractHeartbeat'
require_relative '../credentials'

class ConsoleFormatter < Log4r::Formatter
	def format(event)
		(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end
$log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::INFO, :formatter=>ConsoleFormatter)
$log.add 'err_console'

cmdName = File.basename($0)

if ARGV.empty?
	$stderr.puts "Uasge: #{cmdName} <extractor_id>..."
	exit 1
end

begin
	userData = ExtractUserData::user_data
	
	AWS.config(:access_key_id => AMAZON_ACCESS_KEY_ID, :secret_access_key => AMAZON_SECRET_ACCESS_KEY)
	eeh = Ec2ExtractHeartbeat.new(userData)
	
	while true
		puts Time.now.utc.to_s
		ARGV.each do |eid|
			if (hb = eeh.get_heartbeat(eid))
				puts "\t#{eid}\t--> #{hb.to_s}"
			else
				puts "\t#{eid}\t--> no heartbeat"
			end
		end
		puts
		sleep eeh.heartbeat_interval
	end
	
rescue => err
	puts err.to_s
	puts err.backtrace.join("\n")
end
