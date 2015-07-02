$LOAD_PATH.push("#{File.dirname(__FILE__)}/..")
require 'rubygems'
require "ffi-vix_disk_lib/api_wrapper"
require 'log4r'

#
# Formatter to output log messages to the console.
#
class ConsoleFormatter < Log4r::Formatter
  def format(event)
    (event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
  end
end
$vim_log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level => Log4r::INFO, :formatter => ConsoleFormatter)
$vim_log.add 'err_console'

vmdk = "/vmfs/volumes/StarM1-Dev/Citrix-Mahwah2/Citrix-Mahwah2.vmdk"

VixDiskLibApi  = FFI::VixDiskLib::ApiWrapper
VixDiskLib_raw = FFI::VixDiskLib::API

VixDiskLibApi.init(nil, nil, nil, nil)

tmodes = VixDiskLibApi.list_transport_modes
puts "Transport Modes = [#{tmodes}]"

SERVERNAME = raise "Please define SERVERNAME"
PORTNUMBER = raise "Please define PORTNUMBER"
USERNAME   = raise "Please define USERNAME"
PASSWORD   = raise "Please define PASSWORD"

con_parms = {
  :serverName => SERVERNAME,
  :port       => PORTNUMBER,
  :credType   => VixDiskLib_raw::VIXDISKLIB_CRED_UID,
  :userName   => USERNAME,
  :password   => PASSWORD,
}

connection = VixDiskLibApi.connect(con_parms)

begin
  disk_handle = VixDiskLibApi.open(connection, vmdk, VixDiskLib_raw::VIXDISKLIB_FLAG_OPEN_READ_ONLY)
rescue VixDiskLibError => err
  puts "Error opening #{vmdk}: #{err}.  Exiting test."
  exit
end
dinfo = VixDiskLibApi.get_info(disk_handle)
puts
puts "Disk info:"
dinfo.each { |k, v| puts "\t#{k} => #{v}" }
puts

mode = VixDiskLibApi.get_transport_mode(disk_handle)
puts "Transport Mode: #{mode}"

mkeys = VixDiskLibApi.get_metadata_keys(disk_handle)
puts "Metadata:"
mkeys.each do |k|
  v = VixDiskLibApi.read_metadata(disk_handle, k)
  puts "\t#{k} => #{v}"
end

space = VixDiskLibApi.space_needed_for_clone(disk_handle, :DISK_VMFS_FLAT)
puts "Space Needed for Clone: #{space}"

# nReads = 500000
number_reads = 500
# number_reads = 5000

bytes_read = 0
t0 = Time.now

(0...number_reads).each do |rn|
  read_data = VixDiskLibApi.read(disk_handle, rn, 1)
  bytes_read += read_data.length
end

t1 = Time.now
bps = bytes_read / (t1 - t0)

puts "Read throughput: #{bps} B/s"

VixDiskLibApi.close(disk_handle)
VixDiskLibApi.disconnect(connection)

VixDiskLibApi.exit
