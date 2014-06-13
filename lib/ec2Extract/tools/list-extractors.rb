#!/usr/bin/env ruby

require 'rubygems'
require 'aws-sdk'
require_relative '../credentials'

cmdName = File.basename($0)

begin
	ec2 = AWS::EC2.new(:access_key_id => AMAZON_ACCESS_KEY_ID, :secret_access_key => AMAZON_SECRET_ACCESS_KEY)
	
	puts "EVM extractor instances:"
	ec2.instances.tagged('evm-extractor').each do |ei|
		puts "\t#{ei.id}\t#{ei.status}\t#{ei.launch_time.to_s}"
	end
	
rescue => err
	$stderr.puts "#{cmdName}: #{err.to_s}"
	$stderr.puts err.backtrace.join("\n")
	exit 1
end
