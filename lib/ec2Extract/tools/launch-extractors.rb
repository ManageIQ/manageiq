#!/usr/bin/env ruby

require 'rubygems'
require 'optparse'
require 'aws-sdk'
require_relative '../credentials'
require_relative 'ExtractUserData'
require_relative '../Ec2Payload'

EXTRACTOR_AMI = "miq-extract-images/evm-extract.manifest.xml"

cmdName		= File.basename($0)

availabilityZone	= 'us-east-1b'
keyName				= 'rpo'
logLevel			= 'DEBUG'
numInstance			= 1

#
# Process command line args.
#
OptionParser.new do |opts|
	opts.banner = "Usage: #{cmdName} [options]"

	opts.on('-z', '--availability-zone ARG', "The availability zone in which to access the instance")	do |az|
		availabilityZone = az
	end
	opts.on('-k', '--key-name ARG', "The name of the key pair used to access the instance")	do |kn|
		keyName = kn
	end
	opts.on('-l', '--loglevel ARG', "The log level: DEBUG|INFO|WARN|ERROR|FATAL")	do |ll|
		raise OptionParser::ParseError.new("Unrecognized log level: #{ll}") if !(/DEBUG|INFO|WARN|ERROR|FATAL/i =~ ll)
		logLevel = ll
	end
	opts.on('-n', '--num-instance ARG', "The number of extractor instances to launch")	do |sn|
		n = sn.to_i
		raise OptionParser::ParseError.new("Number of instances must be >= 1") if n < 1
		numInstance = n
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
	userData[:log_level] = logLevel
	userDataEnc = Ec2Payload.encode(userData)
	
	ec2 = AWS::EC2.new(:access_key_id => AMAZON_ACCESS_KEY_ID, :secret_access_key => AMAZON_SECRET_ACCESS_KEY)

	ami = nil
	ec2.images.with_owner('self').each do |i|
		next unless i.location == EXTRACTOR_AMI
		ami = i
		break
	end
	if !ami
		$stderr.puts "#{cmdName}: AMI #{EXTRACTOR_AMI} not found"
		exit 1
	end
	puts "AMI ID: #{ami.id}"
	
	puts "#{cmdName}: launching #{numInstance} " +
			(numInstance == 1 ? 'instance' : 'instances') +
			" of #{EXTRACTOR_AMI}"
	puts "\tavailabilityZone = #{availabilityZone}"
	puts "\tkeyName          = #{keyName}"
	puts "\tlogLevel         = #{logLevel}"
	puts "\tnumInstance      = #{numInstance}"
	puts
	
	ria = ami.run_instances(numInstance,
		:key_name			=> keyName,
		:user_data			=> userDataEnc,
		:availability_zone	=> availabilityZone,
		:instance_type		=> 'm1.large'
	)
	ria = [ria] if ria.kind_of?(AWS::EC2::Instance)
	
	puts "Instances:"
	ria.each do |ri|
		ri.add_tag('Name', :value => 'evm-extractor')
		ri.add_tag('evm-extractor')
		puts "\t#{ri.id}"
	end
	puts
	
rescue => err
	$stderr.puts "#{cmdName}: #{err.to_s}"
	$stderr.puts err.backtrace.join("\n")
	exit 1
end
