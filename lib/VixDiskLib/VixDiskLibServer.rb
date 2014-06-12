
$LOAD_PATH.push("#{File.dirname(__FILE__)}")
$LOAD_PATH.push("#{File.dirname(__FILE__)}/../VMwareWebService")
$LOAD_PATH.push("#{File.dirname(__FILE__)}/../util")

require 'drb/drb'
require 'sync'
require 'vixdisklib_api'
require 'VimTypes'
require 'log4r'
require 'time'
require 'vmdb-logger'

class VixDiskLibError < RuntimeError
end

MIQ_ROOT    = "#{File.dirname(__FILE__)}/../../"
SERVER_PATH = MIQ_ROOT + "lib/VixDiskLib/"
LOG_DIR     = MIQ_ROOT + "vmdb/log/"
LOG_FILE    = LOG_DIR + "vim.log"

$vim_log = VMDBLogger.new LOG_FILE

class << VixDiskLibApi
  alias_method :__disconnect__, :disconnect
  undef :disconnect

  alias_method :__exit__, :exit
  undef :exit

  alias_method :getInfo, :get_info
end

class VixDiskLibServer < VixDiskLibApi
  include DRb::DRbUndumped

  @initialized       = false
  @server_disk_count	= Hash.new { |h, k| h[k] = 0 }
  @vddk              = nil
  def self.server(server)
    return unless @vddk.nil?
    @vddk = server
  end

  @info_log  = ->(s) { $vim_log.info "VMware(VixDiskLib): #{s}" }
  @warn_log  = ->(s) { $vim_log.warn "VMware(VixDiskLib): #{s}" }
  @error_log = ->(s) { $vim_log.error "VMware(VixDiskLib): #{s}" }
  def self.init(info_logger = @info_log, warn_logger = @warn_log, error_logger = @error_log, libDir = nil)
    return if @initialized
    super(info_logger, warn_logger, error_logger, libDir)
    @initialized = true
    @vddk.started = true
    @connection = nil
  end

  def self.dumpDisks(server_name)
    $vim_log.warn "*** Open VdlDisks for server #{server_name}" if $vim_log
    @connection.dumpDisks unless @connection.nil? || @connection.serverName != server_name
    @vddk.running = true
    $vim_log.warn "*** Open VdlDisks end" if $vim_log
  end

  def self.inc_server_disk_count(server_name)
    @server_disk_count[server_name] += 1
    @vddk.running = true
    @server_disk_count[server_name]
  end

  def self.dec_server_disk_count(server_name)
    @server_disk_count[server_name] -= 1
    @vddk.running = true
    @server_disk_count[server_name]
  end

  def self.connect(connect_parms)
    $vim_log.info "VixDiskLibServer.connect: #{connect_parms[:server_name]}" if $vim_log
    raise VixDiskLibError, "VixDiskLib is not initialized" unless @initialized
    raise VixDiskLibError, "Already connected to #{@connection.serverName}" if @connection
    @connection = VdlConnection.new(connect_parms, @vddk)
    @connection
  end

  def self.__disconnect__(conn_obj)
    $vim_log.info "VixDiskLibServer.__disconnect__: #{conn_obj.serverName}" if $vim_log
    raise VixDiskLibError, "VixDiskLib is not initialized" unless @initialized
    super(conn_obj.vdl_connection)
    @connection = nil
  end

  def self.__exit__
    raise VixDiskLibError, "VixDiskLib is not initialized" unless @initialized
    __disconnect__(@connection) unless @connection.nil?
    #
    # NOTE: We have to comment this call out for now.
    # For some reason the call to VixDiskLib.exit is causing
    # the DRb service (this process) to segfault during the exit sequence.
    #
    # super
    $vim_log.info "VixDiskLib has exited cleanly"
    @vddk.running = true
    @vddk.shutdown = true
    @initialized = nil
  end
end # class VixDiskLib

class VdlConnection
  include DRb::DRbUndumped

  attr_reader :vdl_connection, :serverName, :vddk

  MAX_DISK_WARN = 9

  def initialize(connect_parms, vddk)
    @serverName     = connect_parms[:server_name]
    $vim_log.info "VdlConnection.initialize: #{@serverName}" if $vim_log
    @vdl_connection  = VixDiskLibApi.connect(connect_parms)
    @disks           = []
    @disk_lock       = Sync.new
    @vddk            = vddk
  end

  def disconnect
    $vim_log.info "VdlConnection.disconnect: #{@serverName}" if $vim_log
    @disk_lock.synchronize(:EX) do
      if !@vdl_connection
        vim_log.warn "VDLConnection.disconnect: server: #{@serverName} not connected" if $vim_log
      else
        __close_disks__
        VixDiskLibServer.__disconnect__(self)
        @vdl_connection = nil
        @vddk.running = true
        @vddk.shutdown = true
      end
    end
  end

  def dumpDisks
    raise VixDiskLibError, "VdlConnection.getDisk: server #{@serverName} not connected" unless @vdl_connection
    @vddk.running = true
    @disk_lock.sync_lock(:SH) if (unlock = !@disk_lock.sync_locked?)
    @disks.each do |d|
      $vim_log.warn "    VdlDisk: #{d.path}, opened: #{d.timeStamp}" if $vim_log
    end
    ensure
      @disk_lock.sync_unlock if unlock
  end

  def getDisk(path, flags)
    @disk_lock.synchronize(:EX) do
      raise VixDiskLibError, "VdlConnection.getDisk: server #{@serverName} not connected" unless @vdl_connection
      @vddk.running = true
      disk = VdlDisk.new(self, path, flags)
      @disks << disk
      nd = VixDiskLibServer.inc_server_disk_count(@serverName)
      $vim_log.info "VdlConnection.getDisk: #{@serverName} open disks = #{nd}" if $vim_log
      if nd >= MAX_DISK_WARN && $vim_log
        $vim_log.warn "VdlConnection::getDisk: connection to server: #{@serverName}"
        $vim_log.warn "VdlConnection::getDisk: number of open disks = #{nd}"
        $vim_log.warn "VdlConnection::getDisk: subsequent open calls may fail"
        VixDiskLibServer.dumpDisks(@serverName)
      end
      return disk
    end
  end

  def __close_disk__(diskObj)
    @disk_lock.sync_lock(:EX) if (unlock = !@disk_lock.sync_exclusive?)

    @vddk.running = true
    VixDiskLibApi.close(diskObj.handle)
    if !@vdl_connection
      vim_log.warn "VDLConnection.disconnect: server: #{@serverName} not connected" if $vim_log
    else
      @disks.delete(diskObj)
      nd = VixDiskLibServer.dec_server_disk_count(@serverName)
      $vim_log.warn "VdlConnection.__close_disk__: #{@serverName} open disks = #{nd}" if $vim_log
    end
    ensure
      @disk_lock.sync_unlock if unlock
  end

  def __close_disks__
    raise VixDiskLibError,
          "VdlConnection::__close_disks__: exclusive disk lock not held" unless @disk_lock.sync_exclusive?
    if !@vdl_connection
      vim_log.warn "VDLConnection.disconnect: server: #{@serverName} not connected" if $vim_log
    else
      @disks.each { |d| d.close }
    end
  end
  private :__close_disks__
end # class VdlConnection

class VdlDisk
  include DRb::DRbUndumped

  attr_reader :path, :flags, :handle, :sectorSize, :timeStamp, :info

  MIN_SECTORS_TO_CACHE = 64

  def initialize(conn_obj, path, flags)
    @time_stamp = Time.now
    $vim_log.debug "VdlDisk.new <#{object_id}>: opening #{path}" if $vim_log && $vim_log.debug?
    @connection = conn_obj
    @handle = VixDiskLibApi.open(@connection.vdl_connection, path, flags)
    @path = path
    @flags = flags
    @sectorSize = FFI::VixDiskLib::API::VIXDISKLIB_SECTOR_SIZE
    @info = VixDiskLibApi.getInfo(@handle)
    @handle_lock = Sync.new
    @cache = @cache_range = nil

    @num_sectors = @info[:capacity]
    @num_bytes   = @num_sectors * @sectorSize
    @vddk        = conn_obj.vddk
  end

  def close
    $vim_log.debug "VdlDisk.close <#{ssId}>: closing #{@path}" if $vim_log && $vim_log.debug?
    @vddk.running = true
    @handle_lock.synchronize(:EX) do
      if !@handle
        $vim_log.debug "VdlDisk.close: #{@path} not open" if $vim_log && $vim_log.debug?
      else
        @connection.__close_disk__(self)
        @handle = nil
        @cache      = nil
        @cache_range = nil
      end
    end
  end

  def bread(start_sector, num_sectors)
    @vddk.running = true
    @handle_lock.sync_lock(:SH) if (unlock = !@handle_lock.sync_locked?)

    raise VixDiskLibError, "VdlDisk.bread: disk is not open" unless @handle
    return nil if start_sector >= @num_sectors
    num_sectors = @num_sectors - start_sector if (start_sector + num_sectors) > @num_sectors

    return VixDiskLibApi.read(@handle, start_sector, num_sectors)
    ensure
      @handle_lock.sync_unlock if unlock
  end

  def bwrite(start_sector, num_sectors, buf)
    @vddk.running = true
    @handle_lock.sync_lock(:SH) if (unlock = !@handle_lock.sync_locked?)

    raise VixDiskLibError, "VdlDisk.bwrite: disk is not open" unless @handle
    return nil if start_sector >= @num_sectors
    num_sectors = @num_sectors - start_sector if (start_sector + num_sectors) > @num_sectors

    VixDiskLibApi.write(@handle, start_sector, num_sectors, buf)
    return num_sectors
    ensure
      @handle_lock.sync_unlock if unlock
  end

  def breadCached(start_sector, num_sectors)
    @vddk.running = true
    if @cache_range.nil? ||
       !@cache_range.include?(start_sector) ||
       !@cache_range.include?(start_sector + num_sectors - 1)
      sectors_to_read = [MIN_SECTORS_TO_CACHE, num_sectors].max
      @cache        = bread(start_sector, sectors_to_read)
      sectors_read   = @cache.length / @sectorSize
      end_sector     = start_sector + sectors_read - 1
      @cache_range   = Range.new(start_sector, end_sector)
    end

    sector_offset = start_sector  - @cache_range.first
    buffer_offset = sector_offset * @sectorSize
    length       = num_sectors   * @sectorSize

    @cache[buffer_offset, length]
  end

  def read(pos, len)
    @vddk.running = true
    @handle_lock.synchronize(:SH) do
      raise VixDiskLibError, "VdlDisk.read: disk is not open" unless @handle

      return nil if pos >= @num_bytes
      len = @num_bytes - pos if (pos + len) > @num_bytes

      start_sector, start_offset = pos.divmod(@sectorSize)
      end_sector = (pos + len - 1) / @sectorSize
      num_sector = end_sector - start_sector + 1

      r_buf = breadCached(start_sector, num_sector)
      return r_buf[start_offset, len]
    end
  end

  def write(pos, buf, len)
    @vddk.running = true
    @handle_lock.synchronize(:SH) do
      raise VixDiskLibError, "VdlDisk.write: disk is not open" unless @handle

      return nil if pos >= @num_bytes
      len = @num_bytes - pos if (pos + len) > @num_bytes

      start_sector, start_offset = pos.divmod(@sectorSize)
      end_sector = (pos + len - 1) / @sectorSize
      num_sector = end_sector - start_sector + 1
      r_buf = bread(start_sector, num_sector)
      r_buf[start_offset, len] = buf[0, len]
      bwrite(start_sector, num_sector, r_buf)
      return len
    end
  end

  def ssId
    object_id
  end
end # class VdlDisk

class VDDKFactory
  include DRb::DRbUndumped
  attr_accessor :shutdown
  attr_accessor :started
  attr_accessor :running

  def initialize
    @shutdown = nil
    @started = nil
    @running = nil
  end

  def writer_to_caller
    writer_fd = ENV['WRITER_FD']
    writer = IO.new(writer_fd.to_i)
    writer
  end

  def init(info_logger = nil, warn_logger = nil, error_logger = nil, libDir = nil)
    VixDiskLibServer.init(info_logger, warn_logger, error_logger, libDir)
    @started = true
  end

  def connect(connect_parms)
    @running = true
    VixDiskLibServer.connect(connect_parms)
  end

  def shut_down_drb
    thr = DRb.thread
    DRb.stop_service
    thr.join unless thr.nil?
    $vim_log.info "Finished shutting down DRb"
  end

  def shut_down_service(msg)
    t = Time.now.utc.iso8601
    $vim_log.info "[#{t}] (#{Process.pid}) #{msg}"
    VixDiskLibServer.__exit__ if @started
    @running = true
    $vim_log.info "VixDiskLibServer.__exit__ finished"
    shut_down_drb
  end

  #
  # Wait for the client to call our init function.
  # If it isn't called within "max_secs_to_wait" seconds, shut down the service.
  #
  def wait_for_status(status, secs_to_wait)
    start_time = Time.now
    sleep_secs = 2
    flag = (status == "started") ?  @started : @running
    until flag
      sleep sleep_secs
      #
      # Specifically check the shutdown flag in case we've been asked
      # to wait for a different flag.
      #
      break if @shutdown
      #
      # Check if we've waited the specified number of seconds.
      #
      current_time = Time.now
      if current_time - start_time > secs_to_wait
        t = Time.now.utc.iso8601
        elapsed = current_time - start_time
        msg = "[#{t}] (#{Process.pid}) "
        msg += "ERROR: Maximum time for a call to VixDiskLib has been reached after #{elapsed} seconds."
        msg += "\n[#{t}] (#{Process.pid}) Shutting down VixDiskLib Service"
        @shutdown = true
        shut_down_service(msg)
        raise VixDiskLibError, msg
      end
      flag = (status == "started") ?  @started : @running
    end
  end
end # class VDDKFactory

begin
  #
  # The object that handles requests on the server.
  #
  vddk = VDDKFactory.new
  VixDiskLibServer.server(vddk)
  STDOUT.sync = true
  STDERR.sync = true

  DRb.start_service(nil, vddk)
  DRb.primary_server.verbose = true
  uri_used = DRb.uri
  Thread.abort_on_exception = true
  $vim_log.info "Started DRb service on URI #{uri_used}"
  #
  # Now write the URI used back to the parent (client) process to let it know which port was selected.
  #
  writer = vddk.writer_to_caller
  writer.puts "URI:#{uri_used}"
  writer.flush
  #
  # Trap Handlers useful for testing and debugging.
  #
  trap('INT') { vddk.shut_down_service("Interrupt Signal received") && exit }
  trap('TERM') { vddk.shut_down_service("Termination Signal received") && exit }

  #
  # If we haven't been marked as started yet, wait for it.
  # We may return immediately because startup (and more) has already happened.
  #
  $vim_log.info "calling watchdog for startup"
  vddk.wait_for_status("started", 1800)
  $vim_log.info "startup has happened, shutdown flag is #{vddk.shutdown}"
  #
  # Wait for the DRb server thread to finish before exiting.
  #
  until vddk.shutdown
    #
    # Wait no longer than the specified number of seconds for any vddk call, otherwise shut down.
    #
    vddk.wait_for_status("running", 1800)
    Thread.pass unless vddk.shutdown
  end

  vddk.shut_down_service("Shutting Down VixDiskLibServer")
  $vim_log.info "Service has stopped"
rescue => err
  $vim_log.error "VixDiskLibServer ERROR: [#{err}]"
  $vim_log.debug "VixDiskLibServer ERROR: [#{err.backtrace.join("\n")}]"
end
