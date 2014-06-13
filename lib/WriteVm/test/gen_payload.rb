#!/usr/bin/env ruby

$: << "#{File.dirname(__FILE__)}/../../fs"
$: << "#{File.dirname(__FILE__)}/../../fs/MetakitFS"
$: << "#{File.dirname(__FILE__)}/../../fs/MiqFS"
$: << "#{File.dirname(__FILE__)}/../../fs/MiqFS/modules"

require 'rubygems'
require 'log4r'
require 'optparse'
require 'MiqFsUtil'
require 'MiqFS'
require 'MetakitFS'
require 'LocalFS'

yaml	= nil
outFile	= nil
verbose	= false

def pr_usage
	$stderr.puts "Usage: #{File.basename($0)}"
	$stderr.puts "             --yaml <yaml_file> | -y <yaml_file>         #"
	$stderr.puts "             --outfile <output_file> | -o <output_file>  #"
	$stderr.puts "             [--verbose | -v]                            #"
end

#
# Process command line args.
#
opts = OptionParser.new
opts.on('-y', '--yaml [ARG]')			{ |v| yaml = v }
opts.on('-o', '--outfile [ARG]')		{ |v| outFile = v }
opts.on('-v', '--verbose')				{ verbose = true }
opts.parse!(ARGV)

if yaml == nil || outFile == nil
	pr_usage
	exit 1
end

#
# Formatter to output log messages to the console.
#
$stderr.sync = true
class ConsoleFormatter < Log4r::Formatter
	def format(event)
		t = Time.now
		"#{t.hour}:#{t.min}:#{t.sec}: " + (event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end
$log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::ERROR, :formatter=>ConsoleFormatter)
$log.add 'err_console'

dobj = OpenStruct.new
dobj.mkfile = outFile
dobj.create = true

toFs	= MiqFS.new(MetakitFS, dobj)
fromFs	= MiqFS.new(LocalFS, nil)

cf = MiqFsUtil.new(fromFs, toFs, yaml)
cf.verbose = verbose
cf.update

if !toFs.hasTagName?("/", "LABEL")
	puts "*** Adding label..."
	toFs.tagAdd("/", "LABEL=MIQPAYLOAD")
end
