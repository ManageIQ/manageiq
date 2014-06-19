$: << File.join(File.dirname(__FILE__), "../..")
$: << File.join(File.dirname(__FILE__), "../../disk")
$: << File.join(File.dirname(__FILE__), "../../fs/MiqFS")

require 'bundler_setup'
require 'log4r'
require 'ostruct'
require 'MiqDisk'
require 'MiqFS'

#
# Formatter to output log messages to the console.
#
class ConsoleFormatter < Log4r::Formatter
  def format(event)
    (event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
  end
end
$log = Log4r::Logger.new 'toplog'
$log.level = Log4r::DEBUG
Log4r::StderrOutputter.new('err_console', :formatter=>ConsoleFormatter)
$log.add 'err_console'

VIRTUAL_DISK_FILE = "path to disk image file"

begin
  diskInfo = OpenStruct.new
  diskInfo.fileName = VIRTUAL_DISK_FILE

  disk = MiqDisk.getDisk(diskInfo)
  raise "Failed to open disk: #{diskInfo.fileName}" unless disk

  puts "Disk type: #{disk.diskType}"
  puts "Disk partition type: #{disk.partType}"
  puts "Disk block size: #{disk.blockSize}"
  puts "Disk start LBA: #{disk.lbaStart}"
  puts "Disk end LBA: #{disk.lbaEnd}"
  puts "Disk start byte: #{disk.startByteAddr}"
  puts "Disk end byte: #{disk.endByteAddr}"

  parts = disk.getPartitions || []

  i = 1
  parts.each do |p|
    puts "\nPartition #{i}:"
    puts "\tDisk type: #{p.diskType}"
    puts "\tPart partition type: #{p.partType}"
    puts "\tPart block size: #{p.blockSize}"
    puts "\tPart start LBA: #{p.lbaStart}"
    puts "\tPart end LBA: #{p.lbaEnd}"
    puts "\tPart start byte: #{p.startByteAddr}"
    puts "\tPart end byte: #{p.endByteAddr}"
    i += 1
  end

  target_partition = parts.first || disk
  puts "\nTarget partition: #{target_partition.partNum}"

  raise "No filesystem detected" unless (mfs = MiqFS.getFS(target_partition))

  puts "FS type: #{mfs.fsType}"
  puts "pwd = #{mfs.pwd}"

  puts "Files:"
  mfs.dirForeach(".") { |f| puts "\t#{f}" }
rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
ensure
  disk.close if disk
end
