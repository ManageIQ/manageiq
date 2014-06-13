require 'drb'
require 'sync'

class MiqScvmmBroker

	attr_reader :shuttingDown

  @@preLoad        = false
  @@debugUpdates   = false

  def initialize(mode=:client, port="*")
    @mode = mode
    if mode == :client
      #require 'MiqVimDump'
      DRb.start_service
      @broker = DRbObject.new(nil, "druby://localhost:#{port}")
    elsif mode == :server
      require 'MiqScvmmBrokerMods' # only needed by the server
			@shuttingDown = false
			@connectionHash = Hash.new
      @badConnections = Array.new
      @connectionLock = Sync.new
      #DRb.start_service("druby://localhost:#{port}", self)
      DRb.start_service(nil, self)
      puts DRb.uri
    else
      raise "MiqScvmmBroker: unrecognized mode #{mode.to_s}"
    end
  end

  def self.preLoad=(val)
    @@preLoad = val
  end

  def self.preLoad
    @@preLoad
  end

  def self.debugUpdates=(val)
    @@debugUpdates = val
  end

  def self.debugUpdates
    @@debugUpdates
  end

  def getServerHandle(server, username, password)
    svr = nil

    if @mode == :client
      svr = @broker.getServerHandle(server, username, password)
      #vim.instance_eval("extend MiqVimDump")
    else
      key = "#{server}_#{username}"
      @connectionLock.synchronize(:EX) do
				raise "MiqScvmmBroker is shutting down" if @shuttingDown
        svr = @connectionHash[key]
        if svr
          $log.info "MiqScvmmBroker.getMiqVim: found connection for #{key}"
          if svr.isAlive?
            $log.info "MiqScvmmBroker.getMiqVim: returning existing connection for #{key}"
            return(svr)
          end
          $log.info "MiqScvmmBroker.getMiqVim: existing connection for #{key} not alive"
          removeServerHandle(svr)
        end
        $log.info "MiqScvmmBroker.getMiqVim: returning new connection for #{key}"
        svr = DMiqScvmm.new(server, username, password, self, @@preLoad, @@debugUpdates)
        @connectionHash[key] = svr
      end
    end

    return(svr)
  end

  def removeServerHandle(svr_handle)
    return if @mode == :client
    key = "#{svr_handle.server}_#{svr_handle.username}"
    $log.info "MiqScvmmBroker.removeMiqVim: removing connection for #{key}"
    @connectionLock.synchronize(:EX) do
			return if @shuttingDown
      return if !(svr = @connectionHash[key])
      return if svr != svr_handle
      #svr.stopUpdateMonitor
      @badConnections << svr
      @connectionHash.delete(key)
    end
  end

	def shutdown
		raise "MiqScvmmBroker: shutdown cannot be called from client" if @mode == :client
		$log.info "MiqScvmmBroker shutting down..."
		@connectionLock.synchronize(:EX) do
			@shuttingDown = true
			@connectionHash.each do |id, svr|
				$log.info "MiqScvmmBroker: closing connection #{id}"
				#svr.stopUpdateMonitor
				begin
					svr.updateThread.join
				rescue => err
				end
				svr.serverPrivateDisconnect
				@connectionHash.delete(id)
			end
		end
		$log.info "MiqScvmmBroker shutdown complete"
	end

	def serverAlive?
		if @mode == :client
			begin
				return @broker.serverAlive?
			rescue DRb::DRbConnError => err
				return false
			end
		end
		return true
	end

end # class MiqScvmmBroker

