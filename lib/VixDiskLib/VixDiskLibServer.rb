#
# Copyright 2008 ManageIQ, Inc.  All rights reserved.
#

$:.push("#{File.dirname(__FILE__)}")
$:.push("#{File.dirname(__FILE__)}/../VMwareWebService")
$:.push("#{File.dirname(__FILE__)}/../util")

require 'drb/drb'
require 'sync'
require 'vixdisklib_api'
require 'VimTypes'
require 'log4r'
require 'time'
require 'vmdb-logger'

class VixDiskLibError < RuntimeError
end

MIQ_ROOT    = "/var/www/miq/"
SERVER_PATH = MIQ_ROOT + "lib/VixDiskLib/"
LOG_DIR     = MIQ_ROOT + "vmdb/log/"
LOG_FILE    = LOG_DIR + "vim.log"

$vim_log = VMDBLogger.new LOG_FILE

class << VixDiskLibApi
	alias :__disconnect__ :disconnect
	undef :disconnect
	
	alias :__exit__ :exit
	undef :exit

        alias :getInfo :get_info
end

class VixDiskLibServer < VixDiskLibApi
	
	include DRb::DRbUndumped

	
    @@initialized       = false
    @@connectionLock    = Sync.new
    @@serverDiskCount	= Hash.new { |h, k| h[k] = 0 }
  @vddk              = nil
  def self.set_server(server)
    return unless @vddk.nil?
    @vddk = server
  end

        @info_log = lambda { |s| $vim_log.info  "VMware(VixDiskLib): #{s}" }
        @warn_log = lambda { |s| $vim_log.warn  "VMware(VixDiskLib): #{s}" }
        @error_log = lambda { |s| $vim_log.error "VMware(VixDiskLib): #{s}" }
	def self.init(infoLogger = @info_log, warnLogger = @warn_log, errorLogger = @error_log, libDir = nil)
		@@connectionLock.synchronize(:EX) do
			return if @@initialized
			super(@info_log, @warn_log, @error_log, libDir)
			@@connections = Array.new
			@@initialized = true
                        @vddk.started = true
		end
	end

	def self.dumpDisks(serverName)
		$vim_log.warn "*** Open VdlDisks for server #{serverName}" if $vim_log
		@@connectionLock.synchronize(:SH) do
			@@connections.each do |c|
				next if c.serverName != serverName
				c.dumpDisks
			end
                        @vddk.running = true
		end
		$vim_log.warn "*** Open VdlDisks end" if $vim_log
	end

	def self.incServerDiskCount(serverName)
		@@connectionLock.synchronize(:EX) do
			@@serverDiskCount[serverName] += 1
                        @vddk.running = true
			return @@serverDiskCount[serverName]
		end
	end
	
	def self.decServerDiskCount(serverName)
		@@connectionLock.synchronize(:EX) do
			@@serverDiskCount[serverName] -= 1
                        @vddk.running = true
			return @@serverDiskCount[serverName]
		end
	end
	
	def self.connect(connectParms)
		  $vim_log.info "VixDiskLibServer.connect: #{connectParms[:serverName]}" if $vim_log
		@@connectionLock.synchronize(:EX) do
			raise VixDiskLibError, "VixDiskLib is not initialized" if !@@initialized
			connection = VdlConnection.new(connectParms, @vddk)
			@@connections << connection
			$vim_log.info "VixDiskLibServer.connect: total connections = #{@@connections.length}" if $vim_log
			return connection
		end
	end
	
	def self.__disconnect__(connObj)
		$vim_log.info "VixDiskLibServer.__disconnect__: #{connObj.serverName}" if $vim_log
		@@connectionLock.synchronize(:EX) do
			raise VixDiskLibError, "VixDiskLib is not initialized" if !@@initialized
			super(connObj.vdlConnection)
			@@connections.delete(connObj)
			$vim_log.info "VixDiskLibServer.__disconnect__: total connections = #{@@connections.length}" if $vim_log
		end
	end
	
	def self.__exit__
		@@connectionLock.synchronize(:EX) do
			raise VixDiskLibError, "VixDiskLib is not initialized" if !@@initialized
			@@connections.each { |c| self.__disconnect__(c) }
                        #
                        # NOTE: We have to comment this call out for now.
                        # For some reason the call to VixDiskLib.exit is causing
                        # the DRb service (this process) to segfault during the exit sequence.
                        #
			# super
                        t = Time.now.utc.iso8601
                        $vim_log.info "[#{t}] (#{Process.pid}) VixDiskLib has exited cleanly"
                        @vddk.running = true
                        @vddk.shutdown = true
			@@initialized = nil
		end
	end
	
end # class VixDiskLib

class VdlConnection
	
	include DRb::DRbUndumped
	
	attr_reader :vdlConnection, :serverName, :vddk
	
	MAX_DISK_WARN = 9
	
	def initialize(connectParms, vddk)
		@serverName     = connectParms[:serverName]
		$vim_log.info "VdlConnection.initialize: #{@serverName}" if $vim_log
		@vdlConnection  = VixDiskLibApi.connect(connectParms)
		@disks          = Array.new
		@diskLock       = Sync.new
                @vddk           = vddk
	end
	
	def disconnect
		$vim_log.info "VdlConnection.disconnect: #{@serverName}" if $vim_log
		@diskLock.synchronize(:EX) do
			if !@vdlConnection
				vim_log.warn "VDLConnection.disconnect: server: #{@serverName} not connected" if $vim_log
			else
				__closeDisks__
				VixDiskLibServer.__disconnect__(self)
				@vdlConnection = nil
                                @vddk.running = true
                                @vddk.shutdown = true
			end
		end
	end

	def dumpDisks
		begin
			raise VixDiskLibError, "VdlConnection.getDisk: server #{@serverName} not connected" if !@vdlConnection
                        @vddk.running = true
			@diskLock.sync_lock(:SH) if (unlock = !@diskLock.sync_locked?)
			@disks.each do |d|
				$vim_log.warn "    VdlDisk: #{d.path}, opened: #{d.timeStamp}" if $vim_log
			end
		ensure
			@diskLock.sync_unlock if unlock
		end
	end
	
	def getDisk(path, flags)
		@diskLock.synchronize(:EX) do
			raise VixDiskLibError, "VdlConnection.getDisk: server #{@serverName} not connected" if !@vdlConnection
                        @vddk.running = true
			disk = VdlDisk.new(self, path, flags)
			@disks << disk
			nd = VixDiskLibServer.incServerDiskCount(@serverName)
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
	
	def __closeDisk__(diskObj)
		begin
			@diskLock.sync_lock(:EX) if (unlock = !@diskLock.sync_exclusive?)
			
                        @vddk.running = true
			VixDiskLibApi.close(diskObj.handle)
			if !@vdlConnection
				vim_log.warn "VDLConnection.disconnect: server: #{@serverName} not connected" if $vim_log
			else
				@disks.delete(diskObj)
				nd = VixDiskLibServer.decServerDiskCount(@serverName)
				$vim_log.warn "VdlConnection.__closeDisk__: #{@serverName} open disks = #{nd}" if $vim_log
			end
		ensure
			@diskLock.sync_unlock if unlock
		end
	end
	
	def __closeDisks__
		raise VixDiskLibError, "VdlConnection::__closeDisks__: exclusive disk lock not held" if !@diskLock.sync_exclusive?
		if !@vdlConnection
			vim_log.warn "VDLConnection.disconnect: server: #{@serverName} not connected" if $vim_log
		else
			@disks.each { |d| d.close }
		end
	end
	private :__closeDisks__
	
end # class VdlConnection

class VdlDisk
	
	include DRb::DRbUndumped
	
	attr_reader :path, :flags, :handle, :sectorSize, :timeStamp, :info
	
	MIN_SECTORS_TO_CACHE = 64
	
	def initialize(connObj, path, flags)
		@timeStamp = Time.now
		$vim_log.debug "VdlDisk.new <#{self.object_id}>: opening #{path}" if $vim_log && $vim_log.debug?
		@connection = connObj
		@handle = VixDiskLibApi.open(@connection.vdlConnection, path, flags)
		@path = path
		@flags = flags
		@sectorSize = FFI::VixDiskLib::API::VIXDISKLIB_SECTOR_SIZE
		@info = VixDiskLibApi.getInfo(@handle)
		@handleLock = Sync.new
		@cache      = nil
		@cacheRange = nil

		@numSectors = @info[:capacity]
		@numBytes   = @numSectors * @sectorSize
                @vddk       = connObj.vddk
	end
	
	def close
		$vim_log.debug "VdlDisk.close <#{ssId}>: closing #{@path}" if $vim_log && $vim_log.debug?
                @vddk.running = true
		@handleLock.synchronize(:EX) do
			if !@handle
				$vim_log.debug "VdlDisk.close: #{@path} not open" if $vim_log && $vim_log.debug?
			else
				@connection.__closeDisk__(self)
				@handle = nil
				@cache      = nil
				@cacheRange = nil
			end
		end
	end
	
	def bread(startSector, numSectors)
		begin
                        @vddk.running = true
			@handleLock.sync_lock(:SH) if (unlock = !@handleLock.sync_locked?)
			
			raise VixDiskLibError, "VdlDisk.bread: disk is not open" if !@handle
				  return nil if startSector >= @numSectors
				  numSectors = @numSectors - startSector if (startSector + numSectors) > @numSectors
			
			return VixDiskLibApi.read(@handle, startSector, numSectors)
		ensure
			@handleLock.sync_unlock if unlock
		end
	end
	
	def bwrite(startSector, numSectors, buf)
		begin
                        @vddk.running = true
			@handleLock.sync_lock(:SH) if (unlock = !@handleLock.sync_locked?)
		
			raise VixDiskLibError, "VdlDisk.bwrite: disk is not open" if !@handle
				  return nil if startSector >= @numSectors
				  numSectors = @numSectors - startSector if (startSector + numSectors) > @numSectors
			
			VixDiskLibApi.write(@handle, startSector, numSectors, buf)
				  return numSectors
		ensure
			@handleLock.sync_unlock if unlock
		end
	end
	
	def breadCached(startSector, numSectors)
          @vddk.running = true
	  if @cacheRange.nil? || !@cacheRange.include?(startSector) || !@cacheRange.include?(startSector + numSectors - 1)
		sectorsToRead = [MIN_SECTORS_TO_CACHE, numSectors].max
		@cache        = bread(startSector, sectorsToRead)
		sectorsRead   = @cache.length / @sectorSize
		endSector     = startSector + sectorsRead - 1
		@cacheRange   = Range.new(startSector, endSector)
	  end
	  
	  sectorOffset = startSector  - @cacheRange.first
	  bufferOffset = sectorOffset * @sectorSize
	  length       = numSectors   * @sectorSize
	  
	  return @cache[bufferOffset, length]
	end
	
	def read(pos, len)
                @vddk.running = true
		@handleLock.synchronize(:SH) do
			raise VixDiskLibError, "VdlDisk.read: disk is not open" if !@handle

				  return nil if pos >= @numBytes
				  len = @numBytes - pos if (pos + len) > @numBytes
			
			startSector, startOffset = pos.divmod(@sectorSize)
			endSector = (pos+len-1)/@sectorSize
			numSector = endSector - startSector + 1
			
			rBuf = breadCached(startSector, numSector)
			return rBuf[startOffset, len]
		end
	end
	
	def write(pos, buf, len)
                @vddk.running = true
		@handleLock.synchronize(:SH) do
			raise VixDiskLibError, "VdlDisk.write: disk is not open" if !@handle

				  return nil if pos >= @numBytes
				  len = @numBytes - pos if (pos + len) > @numBytes
			
			startSector, startOffset = pos.divmod(@sectorSize)
			endSector = (pos+len-1)/@sectorSize
			numSector = endSector - startSector + 1
			rBuf = bread(startSector, numSector)
			rBuf[startOffset, len] = buf[0, len]
			bwrite(startSector, numSector, rBuf)
			return len
		end
	end

	def ssId
		return(self.object_id)
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

  def init(infoLogger = nil, warnLogger = nil, errorLogger = nil, libDir = nil)
    VixDiskLibServer.init(infoLogger, warnLogger, errorLogger, libDir)
    @started = true
  end

  def connect(connectParms)
    @running = true
    VixDiskLibServer.connect(connectParms)
  end

  def shut_down_drb
    thr = DRb.thread
    DRb.stop_service
    thr.join unless thr.nil?
    timenow = Time.now.utc.iso8601
    $vim_log.info "[#{timenow}] (#{Process.pid}) Finished shutting down DRb"
  end

  def shut_down_service(msg)
    t = Time.now.utc.iso8601
    $vim_log.info "[#{t}] (#{Process.pid}) #{msg}"
    VixDiskLibServer.__exit__ if @started
    @running = true
    t = Time.now.utc.iso8601
    $vim_log.info "[#{t}] (#{Process.pid}) VixDiskLibServer.__exit__ finished"
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

#
# The object that handles requests on the server.
#
vddk = VDDKFactory.new
VixDiskLibServer.set_server(vddk)
STDOUT.sync = true
STDERR.sync = true

DRb.start_service(nil, vddk)
DRb.primary_server.verbose = true
uri_used = DRb.uri
Thread.abort_on_exception = true
t = Time.now.utc.iso8601
$vim_log.info "[#{t}] (#{Process.pid}) Started DRb service on URI #{uri_used}"
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
t = Time.now.utc.iso8601
$vim_log.info "[#{t}] (#{Process.pid}) calling watchdog for startup"
vddk.wait_for_status("started", 1800)
t = Time.now.utc.iso8601
$vim_log.info "[#{t}] (#{Process.pid}) startup has happened, shutdown flag is #{vddk.shutdown}"
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
t = Time.now.utc.iso8601
$vim_log.info "[#{t}] (#{Process.pid}) Service has stopped"
