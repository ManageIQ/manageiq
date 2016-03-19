require 'VMwareWebService/MiqVim'
require 'VMwareWebService/MiqVimUpdate'
require 'VMwareWebService/DMiqVimSync'

#
# Class used to wrap locked object and return it through DRB.
#
class MiqDrbReturn
  attr_accessor :obj, :lock

  def initialize(obj, lock = nil)
    @obj = obj
    @lock = lock
  end
end

class DMiqVim < MiqVim
  alias_method :serverPrivateConnect, :connect
  alias_method :serverPrivateDisconnect, :disconnect
  alias_method :conditionalCopy, :deepClone

  include DRb::DRbUndumped
  include MiqVimUpdate
  include DMiqVimSync

  attr_reader :updateThread

  def initialize(server, username, password, broker, preLoad = false, debugUpdates = false, notifyMethod = nil, cacheScope = nil, maxWait = 60)
    super(server, username, password, cacheScope)

    log_prefix        = "DMiqVim.initialize (#{@connId})"
    @broker         = broker
    @updateMonitorReady   = false
    @error          = nil
    @notifyMethod     = notifyMethod
    @connectionShuttingDown = false
    @connectionRemoved    = false
    @debugUpdates     = debugUpdates
    @maxWait          = maxWait

    checkForOrphanedMonitors
    $vim_log.info "#{log_prefix}: starting update monitor thread" if $vim_log
    @updateThread = Thread.new { monitor(preLoad) }
    @updateThread[:vim_connection_id] = connId
    $vim_log.info "#{log_prefix}: waiting for update monitor to become ready" if $vim_log
    until @updateMonitorReady
      raise @error unless @error.nil?
      break unless @updateThread.alive?
      Thread.pass
    end
    $vim_log.info "#{log_prefix}: update monitor ready" if $vim_log
  end

  # VC sometimes throws: Handsoap::Fault { :code => 'ServerFaultCode', :reason => 'The session is not authenticated.' }
  # Handle this condition by reconnecting and monitoring again
  # See http://communities.vmware.com/thread/190531
  def handleSessionNotAuthenticated(err)
    return false unless err.respond_to?(:reason) && err.reason == 'The session is not authenticated.'

    log_prefix = "DMiqVim.handleSessionNotAuthenticated (#{@connId})"
    $vim_log.error "#{log_prefix}: Reconnecting Session because '#{err.reason}'" if $vim_log
    $vim_log.info "#{log_prefix}: Session(server=#{server}, username=#{username}) isAlive? => #{self.isAlive?.inspect}" if $vim_log

    begin
      $vim_log.info  "#{log_prefix}: Disconnecting Session" if $vim_log
      serverPrivateDisconnect
      $vim_log.info  "#{log_prefix}: Disconnecting Session...Complete" if $vim_log
    rescue => disconnect_err
      $vim_log.error "#{log_prefix}: Disconnecting Session...Error #{disconnect_err}" if $vim_log
    end

    begin
      $vim_log.info  "#{log_prefix}: Connecting Session" if $vim_log
      serverPrivateConnect
      $vim_log.info  "#{log_prefix}: Connecting Session...Complete" if $vim_log
    rescue => connect_err
      $vim_log.error "#{log_prefix}: Connecting Session...Error #{connect_err}" if $vim_log
      @error = err
    end

    @error.nil?
  end

  def monitor(preLoad)
    log_prefix = "DMiqVim.monitor (#{@connId})"
    begin
      monitorUpdates(preLoad)
    rescue Exception => err
      # if handleSessionNotAuthenticated(err)
      #   $vim_log.info "#{log_prefix}: Restarting Update Monitor" if $vim_log
      #   retry
      # end
      $vim_log.info "#{log_prefix}: returned from monitorUpdates via #{err.class} exception" if $vim_log
      @error = err
    ensure
      $vim_log.info "#{log_prefix}: returned from monitorUpdates" if $vim_log
      if @updateMonitorReady && !@broker.shuttingDown
        @broker.connTrySync(:EX, server, username) do |key|
          @broker.removeMiqVimSS(key, self)
        end

        if @notifyMethod
          @notifyMethod.call(:server   => @server,
                             :username => @username,
                             :op       => 'MiqVimRemoved',
                             :error    => @error
                            )
        end
      end
    end
  end

  def shutdownConnection
    return if @connectionShuttingDown
    log_prefix = "DMiqVim.shutdownConnection (#{@connId})"
    $vim_log.info "#{log_prefix}: for address=<#{@server}>, username=<#{@username}>...Starting" if $vim_log
    @connectionShuttingDown = true
    stopUpdateMonitor
    begin
      if @updateThread != Thread.current && @updateThread.alive?
        $vim_log.info "#{log_prefix}: waiting for Update Monitor Thread...Starting" if $vim_log
        @updateThread.join
        $vim_log.info "#{log_prefix}: waiting for Update Monitor Thread...Complete" if $vim_log
      end
    rescue => err
    end
    serverPrivateDisconnect if self.isAlive?
    $vim_log.info "#{log_prefix}: for address=<#{@server}>, username=<#{@username}>...Complete" if $vim_log
  end

  def checkForOrphanedMonitors
    log_prefix = "DMiqVim.checkForOrphanedMonitors (#{@connId})"
    $vim_log.debug "#{log_prefix}: called..."
    Thread.list.each do |thr|
      next unless thr[:vim_connection_id] == connId
      $vim_log.error "#{log_prefix}: Terminating orphaned update monitor <#{thr.object_id}>"
      thr.raise "Orphaned update monitor (#{@connId}) <#{thr.object_id}>, terminated by <#{Thread.current.object_id}>"
      thr.wakeup
    end
    $vim_log.debug "#{log_prefix}: done."
  end

  def connectionRemoved?
    @connectionRemoved
  end

  def connectionRemoved
    @connectionRemoved = true
  end

  def connect
    (true)
  end

  def disconnect
    (true)
  end
end # class DMiqVim
