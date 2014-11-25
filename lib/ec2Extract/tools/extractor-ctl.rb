#!/usr/bin/env ruby

require 'rubygems'
require 'log4r'
require 'optparse'
require 'aws-sdk'

require_relative 'ExtractUserData'
require_relative '../Ec2Payload'
require_relative '../Ec2ExtractQueue'

cmdName			= File.basename($0)
logLevel		= 'DEBUG'
extractorId		= nil
all_extractors	= false
operation		= nil

#
# Process command line args.
#
OptionParser.new do |opts|
	opts.banner = "Usage: #{cmdName} [options]"

	opts.on('-a', '--all', "Perform the operation on all running extractors")	do
		all_extractors = true
	end
	opts.on('-i', '--extractor-id EID', "The AWS ID of the extractor instance")	do |id|
		extractorId = id
	end
	opts.on('-o', '--operation OP', "The control operation: exit|reboot|shutdown")	do |op|
		raise OptionParser::ParseError.new("Unrecognized operation: #{op}") if !(/exit|reboot|shutdown/i =~ op)
		operation = op.downcase.to_sym
	end

	begin
		opts.parse!(ARGV)
		raise OptionParser::MissingArgument.new("--operation")				if operation.nil?
		raise OptionParser::MissingArgument.new("--extractor-id or --all")	if extractorId.nil? && !all_extractors
		raise OptionParser::AmbiguousOption.new("--extractor-id and --all")	if extractorId && all_extractors
	rescue OptionParser::ParseError => perror
		$stderr.puts cmdName + ": " + perror.to_s
		$stderr.puts
		$stderr.puts opts.to_s
		exit 1
	end
end

class ConsoleFormatter < Log4r::Formatter
	def format(event)
		(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end
$log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::INFO, :formatter=>ConsoleFormatter)
$log.add 'err_console'

begin
	
	userData = ExtractUserData::user_data
	userData[:log_level] = logLevel
	
	AWS.config(
		:access_key_id     => userData[:account_info][:access_key_id],
		:secret_access_key => userData[:account_info][:secret_access_key]
	)
	ec2 = AWS::EC2.new
	
	ids = []
	if extractorId
		instance = ec2.instances[extractorId]
		raise "Extractor: #{extractorId}, does not exist" unless instance.exists?
		raise "Extractor: #{extractorId}, is not running" unless instance.status == :running
		ids << extractorId
	else
		ec2.instances.tagged('evm-extractor').each do |ei|
			next unless ei.status == :running
			ids << ei.id
		end
	end
	
	eeq = Ec2ExtractQueue.new(userData)
	
	ids.each do |id|
		puts "#{cmdName}: sending #{operation} request to #{id}"
		case operation
		when :exit
			eeq.send_exit_request(id)
		when :reboot
			eeq.send_reboot_request(id)
		when :shutdown
			eeq.send_shutdown_request(id)
		end
	end
	
rescue => err
	$stderr.puts "#{cmdName}: #{err}"
	$stderr.puts err.backtrace.join("\n")
	exit 1
end
