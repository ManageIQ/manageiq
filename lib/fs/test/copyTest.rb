$: << "#{File.dirname(__FILE__)}/.."
$: << "#{File.dirname(__FILE__)}/../MiqFS"
$: << "#{File.dirname(__FILE__)}/../MetakitFS"
$: << "#{File.dirname(__FILE__)}/../MiqFS/modules"

require 'rubygems'
require 'log4r'
require 'ostruct'
require 'MiqFS'
require 'MiqFsUtil'
require 'MetakitFS'
require 'LocalFS'

SRC_DIR = "../../../vmdb"
DST_DIR = "copy_dst"
MK_FILE = "mkfs"

#
# Formatter to output log messages to the console.
#
$stderr.sync = true
$stdout.sync = true
class ConsoleFormatter < Log4r::Formatter
	def format(event)
		t = Time.now
		"#{t.hour}:#{t.min}:#{t.sec}: " + (event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end
$log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::DEBUG, :formatter=>ConsoleFormatter)
$log.add 'err_console'

#
# First, copy files from the local filesystem to another directory in the local filesystem.
#

fromFs	= MiqFS.new(LocalFS, nil)
toFs	= MiqFS.new(LocalFS, nil)

cf		= MiqFsUtil.new(fromFs, toFs)
cf.verbose = true

#
# Make sure the destination directory exists and is empty.
#
toFs.rmBranch(DST_DIR) if toFs.fileDirectory?(DST_DIR)
toFs.dirMkdir(DST_DIR)

#
# Recursively copy the directory contents.
#
puts "Copying #{SRC_DIR} to #{DST_DIR}"
cf.copy(SRC_DIR, DST_DIR, true)
puts "copy complete"

#
# Compare the contents of the original directory to that of its copy.
# They should be the same.
#
dd = File.join(DST_DIR, File.basename(SRC_DIR))
puts "Comparing #{SRC_DIR} to #{dd}"
system("diff", "-qr", SRC_DIR, dd)
if $?.exitstatus != 0
	puts "FAIL: Directory contents are not the same"
	exit($?.exitstatus)
else
	puts "SUCCESS: Directory contents match"
end

#
# Now, copy files from the local filesystem to a metakit filesystem.
#

#
# Create a new metakit filesystem.
#
File.delete(MK_FILE) if File.exists?(MK_FILE)
dobj = OpenStruct.new
dobj.mkfile = MK_FILE
dobj.create = true
toFs = MiqFS.new(MetakitFS, dobj)

#
# Set the new metakit filssystem as the destination of the copy.
#
cf.toFs = toFs

#
# Recursively copy the directory contents.
#
puts "Copying #{SRC_DIR} to / (on mkfs)"
cf.copy(SRC_DIR, "/", true)
puts "copy complete"

#
# Now, reverse the copy.
# Copy files out of the metakit FS to the local FS.
#
fromFs, toFs = toFs, fromFs
cf.toFs = toFs
cf.fromFs = fromFs

#
# Make sure the destination directory exists and is empty.
#
toFs.rmBranch(DST_DIR) if toFs.fileDirectory?(DST_DIR)
toFs.dirMkdir(DST_DIR)

puts
puts "Copying /vmdb (on mkfs) to #{DST_DIR}"
cf.copy("/vmdb", DST_DIR, true)
puts "copy complete"

#
# Compare the contents of the original directory to that of its copy.
# They should be the same.
#
puts
puts "Comparing #{SRC_DIR} to #{dd}"
system("diff", "-qr", SRC_DIR, dd)
if $?.exitstatus != 0
	puts "FAIL: Directory contents are not the same"
	exit($?.exitstatus)
else
	puts "SUCCESS: Directory contents match"
end

#
# Clean up.
#
File.delete(MK_FILE) if File.exists?(MK_FILE)
toFs.rmBranch(DST_DIR) if toFs.fileDirectory?(DST_DIR)
