#!/usr/bin/env ruby

$:.push("#{File.dirname(__FILE__)}/../../util")

require 'rubygems'
require 'log4r'
require 'optparse'
require 'miq-xml'

require_relative '../credentials'
require_relative '../Ec2ExtractQueue'
require_relative '../tools/ExtractUserData'

class ConsoleFormatter < Log4r::Formatter
	def format(event)
		(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end
$log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::INFO, :formatter=>ConsoleFormatter)
$log.add 'err_console'

cmdName = File.basename($0)
verbose = false

#
# Process command line args.
#
OptionParser.new do |opts|
	opts.banner = "Usage: #{cmdName} [options]"

	opts.on('-v', '--verbose', "Include extracted data in output")	do
		verbose = true
	end
	begin
		opts.parse!(ARGV)
	rescue OptionParser::ParseError => perror
		$stderr.puts cmdName + ": " + perror.to_s
		$stderr.puts
		$stderr.puts opts.to_s
		exit 1
	end
end

begin

	userData = ExtractUserData::user_data
	
	AWS.config(:access_key_id => AMAZON_ACCESS_KEY_ID, :secret_access_key => AMAZON_SECRET_ACCESS_KEY)
	eeq = Ec2ExtractQueue.new(userData)
	
	puts
	eeq.get_reply_loop do |reply_data|
		msg			= reply_data[:sqs_msg]
		req_id		= reply_data[:request_id]
		reply_type	= reply_data[:reply_type]
		
		puts "Message: #{msg.id} - from: #{reply_data[:extractor_id]} - reply to request: #{req_id}"
		
		case reply_type
		when :extract
			puts "\treply_type: #{reply_data[:reply_type]}"
			puts "\tec2_id:     #{reply_data[:ec2_id]}"
			puts "\tstart_time: #{reply_data[:start_time]}"
			puts "\tend_time:   #{reply_data[:end_time]}"
			if reply_data[:error]
				puts "\tstatus:     ERROR"
				puts "\terror:      #{reply_data[:error]}"
			else
				puts "\tstatus:     OK"
			end
		
			reply_data[:categories].each do |cat, xml_str|
				mxml = MiqXml.load(xml_str)
				puts
				puts "*** #{cat} START"
				mxml.to_xml.write($stdout, 4)
				puts
				puts "*** #{cat} END"
			end if verbose
		when :exit, :reboot, :shutdown
			puts "\treply_type:   #{reply_data[:reply_type]}"
			puts "\textractor_id: #{reply_data[:extractor_id]}"
			puts "\trequest_id:   #{reply_data[:request_id]}"
		else
			puts "Unrecognized reply type: #{reply_type}"
		end
		puts
		msg.delete
	end
	
rescue => err
	puts err.to_s
	puts err.backtrace.join("\n")
end
