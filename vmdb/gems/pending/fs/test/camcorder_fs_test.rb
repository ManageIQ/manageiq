$:.push(File.join(File.dirname(__FILE__), "../.."))
$:.push(File.join(File.dirname(__FILE__), "../../disk"))
$:.push(File.join(File.dirname(__FILE__), "../../fs/MiqFS"))

require 'bundler_setup'
require 'openssl' # Required for 'Digest' in camcorder (< Ruby 2.1)
require 'camcorder'
require 'log4r'
require 'ostruct'
require 'MiqDisk'
require 'MiqFS'
require 'modules/MiqLargeFile'

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
Log4r::StderrOutputter.new('err_console', :formatter => ConsoleFormatter)
$log.add 'err_console'

#
# Path to RAW disk image.
#
VIRTUAL_DISK_FILE = "path to raw disk image file"

commit = true

begin
  recorder = Camcorder::Recorder.new("#{File.dirname(__FILE__)}/foo.yml")
  Camcorder.default_recorder = recorder
  Camcorder.intercept_constructor(MiqLargeFile::MiqLargeFileOther) do
    methods_with_side_effects :seek, :read, :write
  end
  Camcorder.intercept_constructor(MiqLargeFile::MiqLargeFileStat)

  recorder.start

  diskInfo = OpenStruct.new
  diskInfo.rawDisk = true # remove if image is not in RAW format.
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

  all_paths    = mfs.find('/')
  directories  = all_paths.select { |p| mfs.fileDirectory?(p) }
  files        = all_paths.select { |p| mfs.fileFile?(p) }
  sym_links    = all_paths.select { |p| mfs.fileSymLink?(p) }
  unclassified = all_paths - directories - files - sym_links

  puts "files:        #{files.length}"
  puts "directories:  #{directories.length}"
  puts "sym_links:    #{sym_links.length}"
  puts "unclassified: #{unclassified.length}"
  puts "total:        #{files.length + directories.length + sym_links.length + unclassified.length}"
  puts "all_paths:    #{all_paths.length}"

  unless unclassified.empty?
    puts
    puts "unclassified files:"
    unclassified.each { |p| puts "\t#{p}" }
  end
rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
  commit = false # don't commit recording on error
ensure
  disk.close if disk
  if recorder && commit
    puts
    puts "camcorder: committing recording..."
    recorder.commit
    puts "done."
  end
end
