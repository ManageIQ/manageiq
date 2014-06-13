#!/usr/bin/env ruby

require 'optparse'
require "../MiqPayloadOutputter"

MB = 1024 * 1024
BLOCK_SIZE = 512

outFile	= nil
size = -1

def pr_usage
	$stderr.puts "Usage: #{File.basename($0)}"
	$stderr.puts "             --outfile <output_file> | -o <output_file>  #"
	$stderr.puts "             --size <size_in_bytes> | -s <size_in_bytes> #"
	$stderr.puts "             --sizemb <size_in_mb> | -S <size_in_mb>     #"
end

#
# Process command line args.
#
opts = OptionParser.new
opts.on('-o', '--outfile [ARG]')		{ |v| outFile = v }
opts.on('-s', '--size [ARG]')			{ |v| size = v.to_i }
opts.on('-S', '--sizemb [ARG]')			{ |v| size = v.to_i * MB }
opts.parse!(ARGV)

if size <= 0 || outFile == nil
	pr_usage
	exit 1
end

size += BLOCK_SIZE - (size % BLOCK_SIZE) if size % BLOCK_SIZE != 0
puts "Log size: #{size}"

out = File.new(outFile, "w")

if out.write(Log4r::MiqPayloadOutputter.genHeader(size)) != Log4r::MiqPayloadOutputter::HEADER_SIZE
	$stderr.puts "Could not write header to log file."
	exit 1
end

buf = "\000" * BLOCK_SIZE
n = size/BLOCK_SIZE

(0...n).each { out.write(buf) }
out.close

exit 0
