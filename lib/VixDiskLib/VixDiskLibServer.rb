#
# Copyright 2008 ManageIQ, Inc.  All rights reserved.
#

$:.push("#{File.dirname(__FILE__)}")

require 'drb/drb'
require 'sync'
require 'vixdisklib_api'

#
# The URI to connect to will be constructed from the prefix and have the port number appended.
#
SERVER_URI_PREFIX = "druby://localhost:"
#
# Temporarily hard-coded port number.  This will be dynamically allocated and
# passed to the spawned server in the final version.
#
SERVER_URI_PORT = "10115"

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

        @info_log = lambda { |s| $vim_log.info  "VMware(VixDiskLib): #{s}" }
        @warn_log = lambda { |s| $vim_log.warn  "VMware(VixDiskLib): #{s}" }
        @error_log = lambda { |s| $vim_log.error "VMware(VixDiskLib): #{s}" }
	def self.init(infoLogger=@info_log, warnLogger=@warn_log, errorLogger=@error_log, libDir=nil)
		@@connectionLock.synchronize(:EX) do
			return if @@initialized
			#super(infoLogger, warnLogger, errorLogger, libDir)
			super(@info_log, @warn_log, @error_log, libDir)
			@@connections = Array.new
			@@initialized = true
			at_exit { self.__exit__ }
		end
	end

	def self.dumpDisks(serverName)
		$vim_log.warn "*** Open VdlDisks for server #{serverName}" if $vim_log
		@@connectionLock.synchronize(:SH) do
			@@connections.each do |c|
				next if c.serverName != serverName
				c.dumpDisks
			end
		end
		$vim_log.warn "*** Open VdlDisks end" if $vim_log
	end

	def self.incServerDiskCount(serverName)
		@@connectionLock.synchronize(:EX) do
			@@serverDiskCount[serverName] += 1
			return @@serverDiskCount[serverName]
		end
	end
	
	def self.decServerDiskCount(serverName)
		@@connectionLock.synchronize(:EX) do
			@@serverDiskCount[serverName] -= 1
			return @@serverDiskCount[serverName]
		end
	end
	
	def self.connect(connectParms)
		  $vim_log.info "VixDiskLibServer.connect: #{connectParms[:serverName]}" if $vim_log
		@@connectionLock.synchronize(:EX) do
			raise "VixDiskLib is not initialized" if !@@initialized
			connection = VdlConnection.new(connectParms)
			@@connections << connection
			$vim_log.info "VixDiskLibServer.connect: total connections = #{@@connections.length}" if $vim_log
			return connection
		end
	end
	
	def self.__disconnect__(connObj)
		$vim_log.info "VixDiskLibServer.__disconnect__: #{connObj.serverName}" if $vim_log
		@@connectionLock.synchronize(:EX) do
			raise "VixDiskLib is not initialized" if !@@initialized
			super(connObj.vdlConnection)
			@@connections.delete(connObj)
			$vim_log.info "VixDiskLibServer.__disconnect__: total connections = #{@@connections.length}" if $vim_log
		end
	end
	
	def self.__exit__
		@@connectionLock.synchronize(:EX) do
			raise "VixDiskLib is not initialized" if !@@initialized
			@@connections.each { |c| self.__disconnect__(c) }
			super
			@@initialized = nil
		end
	end
	
end # class VixDiskLib

class VdlConnection
	
	include DRb::DRbUndumped
	
	attr_reader :vdlConnection, :serverName
	
	MAX_DISK_WARN = 9
	
	def initialize(connectParms)
		@serverName     = connectParms[:serverName]
		$vim_log.info "VdlConnection.initialize: #{@serverName}" if $vim_log
		@vdlConnection  = VixDiskLibApi.connect(connectParms)
		@disks          = Array.new
		@diskLock       = Sync.new
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
			end
		end
	end

	def dumpDisks
		begin
			raise "VdlConnection.getDisk: server #{@serverName} not connected" if !@vdlConnection
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
			raise "VdlConnection.getDisk: server #{@serverName} not connected" if !@vdlConnection
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
		raise "VdlConnection::__closeDisks__: exclusive disk lock not held" if !@diskLock.sync_exclusive?
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
		@sectorSize = VixDiskLibApi::VIXDISKLIB_SECTOR_SIZE
		@info = VixDiskLibApi.getInfo(@handle)
		@handleLock = Sync.new
		@cache      = nil
		@cacheRange = nil

		@numSectors = @info[:capacity]
		@numBytes   = @numSectors * @sectorSize
	end
	
	def close
		$vim_log.debug "VdlDisk.close <#{ssId}>: closing #{@path}" if $vim_log && $vim_log.debug?
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
			@handleLock.sync_lock(:SH) if (unlock = !@handleLock.sync_locked?)
			
			raise "VdlDisk.bread: disk is not open" if !@handle
				  return nil if startSector >= @numSectors
				  numSectors = @numSectors - startSector if (startSector + numSectors) > @numSectors
			
			return VixDiskLibApi.read(@handle, startSector, numSectors)
		ensure
			@handleLock.sync_unlock if unlock
		end
	end
	
	def bwrite(startSector, numSectors, buf)
		begin
			@handleLock.sync_lock(:SH) if (unlock = !@handleLock.sync_locked?)
		
			raise "VdlDisk.bwrite: disk is not open" if !@handle
				  return nil if startSector >= @numSectors
				  numSectors = @numSectors - startSector if (startSector + numSectors) > @numSectors
			
			VixDiskLibApi.write(@handle, startSector, numSectors, buf)
				  return numSectors
		ensure
			@handleLock.sync_unlock if unlock
		end
	end
	
	def breadCached(startSector, numSectors)
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
		@handleLock.synchronize(:SH) do
			raise "VdlDisk.read: disk is not open" if !@handle

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
		@handleLock.synchronize(:SH) do
			raise "VdlDisk.write: disk is not open" if !@handle

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

  def initialize
  end

  def set_handle(drb_handle)
    @DRB = drb_handle
  end

  def init(infoLogger = nil, warnLogger = nil, errorLogger = nil, libDir = nil)
    VixDiskLibServer.init(infoLogger, warnLogger, errorLogger, libDir)
  end

  def connect(connectParms)
    VixDiskLibServer.connect(connectParms)
  end

  def shut_down_service(msg)
    puts "VDDKFactory.shut_down_service called with message #{msg}"
    # @DRB.stop_service
  end
end

#
# The object that handles requests on the server.
#
vddk_server = VDDKFactory.new
puts "Created DRB Server Object"
vddk_server.set_handle(DRb)

DRb.start_service(SERVER_URI_PREFIX + SERVER_URI_PORT, vddk_server)
puts "Started DRB Server on #{SERVER_URI_PREFIX}#{SERVER_URI_PORT}"
#
# Wait for the DRb server thread to finish before exiting.
#
trap('INT') { DRb.thread.kill; exit }
DRb.thread.join
puts "Service has stopped"
