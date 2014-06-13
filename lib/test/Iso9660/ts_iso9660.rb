# The test needs an .iso file as an argument

if ARGV[0].nil?
	puts "Supply an .iso file as an argument."
	puts "Example: ts_iso9660 myimage.iso"
	exit
end

$rawDisk = ARGV[0].dup
puts "Testing with #{ARGV[0]}"
require 'tc_iso9660BootSector'
require 'tc_iso9660FileSystem'
require 'tc_iso9660Directory'