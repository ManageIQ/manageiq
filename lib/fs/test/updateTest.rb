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

SRC_DIR		= "../../../vmdb"
DST_DIR		= "copy_dst"
REF_DIR		= "copy_dst_ref"
MK_FILE		= "mkfs"
MK_FILE_NC	= "mkfs_nc"

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

fromFs	= MiqFS.new(LocalFS, nil)
toFs	= MiqFS.new(LocalFS, nil)

cf		= MiqFsUtil.new(fromFs, toFs, "collect_files_direct.yaml")
cf.verbose = true

#
# Make sure the destination directory exists and is empty.
#
toFs.rmBranch(REF_DIR) if toFs.fileDirectory?(REF_DIR)
toFs.dirMkdir(REF_DIR)

puts "*** Collecting files from #{SRC_DIR} to #{REF_DIR}"
cf.update

#
# Collect the same files from the same directory into a mkfs.
#

#
# Create a new metakit filesystem.
#
File.delete(MK_FILE_NC) if File.exists?(MK_FILE_NC)
dobj = OpenStruct.new
dobj.mkfile = MK_FILE_NC
dobj.create = true
mkFs_nc = MiqFS.new(MetakitFS, dobj)

#
# Set the new metakit filssystem as the destination of the copy.
#
cf.toFs = mkFs_nc
cf.updateSpec = "collect_files_in_nc.yaml"

puts
puts "*** Collecting files from #{SRC_DIR} to /vmdb (mkfs no compression)"
cf.update

#
# Now collect the same files from the same directory into a mkfs,
# compressing the files.
#

#
# Create a new metakit filesystem.
#
File.delete(MK_FILE) if File.exists?(MK_FILE)
dobj = OpenStruct.new
dobj.mkfile = MK_FILE
dobj.create = true
mkFs = MiqFS.new(MetakitFS, dobj)

#
# Set the new metakit filssystem as the destination of the copy.
#
cf.toFs = mkFs
cf.updateSpec = "collect_files_in.yaml"

puts
puts "*** Collecting files from #{SRC_DIR} to /vmdb (mkfs compressed)"
cf.update

mkFileNcSize	= File.size(MK_FILE_NC).to_f
mkFileSize		= File.size(MK_FILE).to_f

puts "Metakit file size: #{mkFileNcSize}, Compressed: #{mkFileSize}, #{(mkFileNcSize-mkFileSize)/mkFileNcSize*100}% cpmpression"

#
# Now set up to reverse the copy, copying out of the mkfs to the local fs.
#
cf.toFs = cf.fromFs
cf.fromFs = mkFs_nc
cf.updateSpec = "collect_files_out.yaml"

#
# Make sure the destination directory exists and is empty.
#
cf.toFs.rmBranch(DST_DIR) if cf.toFs.fileDirectory?(DST_DIR)
cf.toFs.dirMkdir(DST_DIR)

puts
puts "*** Collecting files from /vmdb (mkfs not compressed) to #{DST_DIR}"
cf.update

#
# Compare the contents of the original directory to that of its copy.
# They should be the same.
#
puts "Comparing #{REF_DIR} to #{DST_DIR}"
system("diff", "-qr", REF_DIR, DST_DIR)
if $?.exitstatus != 0
	puts "FAIL: Directory contents are not the same"
	exit($?.exitstatus)
else
	puts "SUCCESS: Directory contents match"
end

#
# Now, copy out of the compressed mkfs, and compare the same way.
#

cf.fromFs = mkFs

#
# Make sure the destination directory exists and is empty.
#
cf.toFs.rmBranch(DST_DIR) if cf.toFs.fileDirectory?(DST_DIR)
cf.toFs.dirMkdir(DST_DIR)

puts
puts "*** Collecting files from /vmdb (mkfs compressed) to #{DST_DIR}"
cf.update

#
# Compare the contents of the original directory to that of its copy.
# They should be the same.
#
puts "Comparing #{REF_DIR} to #{DST_DIR}"
system("diff", "-qr", REF_DIR, DST_DIR)
if $?.exitstatus != 0
	puts "FAIL: Directory contents are not the same"
	exit($?.exitstatus)
else
	puts "SUCCESS: Directory contents match"
end

#
#  Test the remove code.
#
cf.updateSpec = "collect_files_rm.yaml"
puts
puts "*** Removing files from #{DST_DIR}"
cf.update

#
# Compare the contents of the original directory to that of its copy.
# They should be different.
#
puts
puts "Comparing #{REF_DIR} to #{DST_DIR}"
system("diff", "-qr", REF_DIR, DST_DIR)
if $?.exitstatus == 0
	puts "FAIL: Directory contents are the same"
	exit($?.exitstatus)
else
	puts "SUCCESS: Directory contents don't match"
end

#
# Clean up.
#
File.delete(MK_FILE) if File.exists?(MK_FILE)
File.delete(MK_FILE_NC) if File.exists?(MK_FILE_NC)
toFs.rmBranch(DST_DIR) if toFs.fileDirectory?(DST_DIR)
toFs.rmBranch(REF_DIR) if toFs.fileDirectory?(REF_DIR)
