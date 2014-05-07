require 'drb/drb'
require 'VixDiskLib_FFI/const'
#
# Alias the New FFI Binding Class Name to the old C Binding Class Name
#
VixDiskLib_raw = FFI::VixDiskLib::API

#
# The URI to connect to will be constructed from the prefix and have the port number appended.
#
SERVER_URI_PREFIX = "druby://localhost:"
#
# Temporarily hard-coded port number.  This will be dynamically allocated and
# passed to the spawned server as an environment variable in the final version.
#
SERVER_URI_PORT = "10115"
DRb.start_service

# class VixDiskLibClient
class VixDiskLib
  @vix_disk_lib_service = nil
  VIXDISKLIB_FLAG_OPEN_READ_ONLY = FFI::VixDiskLib::API::VIXDISKLIB_FLAG_OPEN_READ_ONLY

  def self.init(info_logger = nil, warn_logger = nil, error_logger = nil, lib_dir = nil)
    if @vix_disk_lib_service.nil?
      puts "VixDiskLibClient.init() starting"
      puts "VixDiskLibClient.init() getting DRbObject"
      @vix_disk_lib_service = DRbObject.new_with_uri(SERVER_URI_PREFIX + SERVER_URI_PORT)
      puts "VixDiskLibClient.init() calling remote init"
      @vix_disk_lib_service.init(info_logger, warn_logger, error_logger, lib_dir)
      puts "VixDiskLibClient.init() stopping"
      nil
    else
      #
      # Print an error, raise an error, log an error.....
      #
    end
  end

  def self.connect(connect_parms)
    puts "VixDiskLibClient.connect() starting"
    connection = @vix_disk_lib_service.connect(connect_parms)
    puts "VixDiskLibClient.connect() stopping"
    connection
  end

  def self.disconnect(connection)
    puts "VixDiskLibClient.disconnect() starting"
    @vix_disk_lib_service.disconnect(connection) unless connection.nil?
    puts "VixDiskLibClient.disconnect() stopping"
  end

  def self.open(connection, path, flags)
    puts "VixDiskLibClient.open() starting"
    @vix_disk_lib_service.open(connection, path, flags)
    puts "VixDiskLibClient.open() stopping"
  end

  def self.close(disk_handle)
    puts "VixDiskLibClient.close() starting"
    @vix_disk_lib_service.close(disk_handle)
    puts "VixDiskLibClient.close() stopping"
  end

  def self.get_info(disk_handle)
    puts "VixDiskLibClient.get_info() starting"
    @vix_disk_lib_service.get_info(disk_handle)
    puts "VixDiskLibClient.get_info() stopping"
  end

  def self.read(disk_handle, start_sector, num_sectors)
    puts "VixDiskLibClient.read() starting"
    @vix_disk_lib_service.read(disk_handle, start_sector, num_sectors)
    puts "VixDiskLibClient.read() stopping"
  end

  def self.write(disk_handle, start_sector, num_sectors, buf)
    puts "VixDiskLibClient.write() starting"
    @vix_disk_lib_service.write(disk_handle, start_sector, num_sectors, buf)
    puts "VixDiskLibClient.write() stopping"
  end

  def self.vix_disk_lib_sector_size
    puts "VixDiskLibClient.vix_disk_lib_sector_size() starting"
    @vix_disk_lib_service.sector_size
  end

  def self.exit
    puts "VixDiskLibClient.exit() starting"
    unless @vix_disk_lib_service.nil?
      @vix_disk_lib_service.shut_down_service("Say Bye-Bye!!")
      DRb.stop_service
      @vix_disk_lib_service = nil
    end
    puts "VixDiskLibClient.exit() stopping"
  end
end
