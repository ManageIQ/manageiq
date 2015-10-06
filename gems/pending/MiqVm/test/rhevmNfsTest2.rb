#
# This test assumes the NFS share of the storage in question is mounted on the appliance.
#

require_relative '../../bundler_setup'
require 'log4r'
require 'ostruct'
require 'MiqVm/MiqVm'

class ConsoleFormatter < Log4r::Formatter
  def format(event)
    (event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
  end
end

toplog = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level => Log4r::DEBUG, :formatter => ConsoleFormatter)
toplog.add 'err_console'
$log = toplog if $log.nil?

DDIR = "/mnt/vm/7fd0b9b2-e362-11e2-97b7-001a4aa8fcea/rhev/data-center/773f2ddf-7765-42fc-85d6-673b718541cd/aa7e70e5-40d0-43e2-a605-92ce6ba652a8/images/19449cf8-1905-4b8a-b45a-e845a693a3df"
BASE_FILE = "#{DDIR}/903306be-f676-4005-a813-daa6d7a6c33f"
REDO_FILE = "#{DDIR}/9e7075c5-a014-4ddf-a168-a33723d0c3cd"

# DISK_FILE = BASE_FILE
DISK_FILE = REDO_FILE

diskid    = "scsi0:0"
hardware  = "#{diskid}.present = \"TRUE\"\n"
hardware += "#{diskid}.filename = \"#{DISK_FILE}\"\n"

begin
  puts
  puts `file #{DISK_FILE}`
  puts

  ost = OpenStruct.new
  ost.fileName = DISK_FILE

  unless (disk = MiqDisk.getDisk(ost))
    puts "Failed to open disk"
    exit(1)
  end

  unless (parts = disk.getPartitions)
    puts "No partitions detected"
    exit(1)
  end

  unless (part = parts.detect { |p| p.partNum == 1 })
    puts "Could not find partition 1"
    exit(1)
  end

  unless (mfs = MiqFS.getFS(part))
    puts "No filesystem detected"
    exit(1)
  end

  puts "Found #{mfs.fsType} filesystem"
rescue => err
  $log.error err.to_s
  $log.error err.backtrace.join("\n")
ensure
  # vm.unmount if vm
end
