require 'workers/worker_base'
require 'thread'
require 'sync'

class SmisRefreshWorker < WorkerBase
  self.wait_for_worker_monitor = true  # SmisRefreshWorker uses the VimBrokerWorker

  def after_initialize
    _log.info "starting"

    @smis_update_period   = self.worker_settings[:smis_update_period]   || 60 * 30
    @status_update_period = self.worker_settings[:status_update_period] || 60 * 5
    @stats_update_period  = self.worker_settings[:stats_update_period]  || 60 * 10

    _log.info "smis_update_period:   #{@smis_update_period}"
    _log.info "status_update_period: #{@status_update_period}"
    _log.info "stats_update_period:  #{@stats_update_period}"

    @updateLock = Sync.new
    @flagLock = Sync.new

    @smis_update_thread   = nil
    @status_update_thread = nil
    @stats_update_thread  = nil

    @smis_update_in_progress  = false
    @status_update_in_progress  = false
    @smis_update_requested    = false
    @status_update_requested  = false
  end

  def do_before_work_loop
    @exiting = false
    start_smis_update_thread
  end

  def start_smis_update_thread
    return if @exiting

    _log.info "starting smis_update_thread"

    @smis_update_thread = Thread.new do
      @flagLock.synchronize(:EX) do
        @smis_update_in_progress = true
        @smis_update_requested = false
        @status_update_requested = false # this update will take care of this too
      end

      updated = false

      #
      # XXX Should this lock be moved into MiqSmisAgent?
      # It assumes only one process per-zone will perform updates.
      #
      @updateLock.synchronize(:EX) do
        begin
          _log.info "update_smis start"
          updated = MiqSmisAgent.update_smis(MiqSmisProfiles.extractProfile)
        rescue => err
          _log.error "update_smis - #{err}"
          _log.error err.backtrace.join("\n")
        ensure
          _log.info "update_smis end"
        end
      end
      #
      # This should be moved. It needs to be performed after a VMDB update.
      #
      # _log.info "update_from_vmdb start"
      # begin
      #   if updated
      #     MiqSmisAgent.update_from_vmdb
      #   else
      #     _log.info "skipping update_from_vmdb, no updates from smis"
      #   end
      # rescue => err
      #   _log.error "update_from_vmdb - #{err.to_s}"
      #   $log.error err.backtrace.join("\n")
      # end
      # _log.info "update_from_vmdb end"

      @updateLock.synchronize(:EX) do
        _log.info "cleanup start"
        begin
          MiqSmisAgent.cleanup
        rescue => err
          _log.error "cleanup - #{err}"
          $log.error err.backtrace.join("\n")
        end
        _log.info "cleanup end"
      end
      @smis_update_requested = false
      @status_update_requested = false # this update will take care of this too
      @smis_update_in_progress = false

      break if @exiting

      start_status_update_thread  if !@status_update_thread || !@status_update_thread.alive?
      start_stats_update_thread if !@stats_update_thread || !@stats_update_thread.alive?

      loop do
        begin
          @flagLock.sync_lock(:EX)
          @smis_update_in_progress = false

          unless @smis_update_requested
            @flagLock.sync_unlock
            _log.info "update_smis sleeping #{@smis_update_period}"
            slept = 0
            while slept < @smis_update_period do
              sv = sleep @smis_update_period
              if @smis_update_requested
                @flagLock.sync_lock(:EX)
                @smis_update_requested = false
                @status_update_requested = false # this update will take care of this too
                break
              end
              slept += sv
            end
          else
            @smis_update_requested = false
            @status_update_requested = false # this update will take care of this too
          end

          break if @exiting
          @smis_update_in_progress = true
        ensure
          @flagLock.sync_unlock if @flagLock.sync_locked?
        end

        @updateLock.synchronize(:EX) do
          begin
            _log.info "update_smis start"
            MiqSmisAgent.update_smis(MiqSmisProfiles.extractProfile)
          rescue => err
            _log.error "update_smis - #{err}"
            _log.error err.backtrace.join("\n")
          ensure
            _log.info "update_smis end"
          end
        end
        #
        # This should be moved. It needs to be performed after a VMDB update.
        #
        # _log.info "update_from_vmdb start"
        # begin
        #   MiqSmisAgent.update_from_vmdb
        # rescue => err
        #   _log.error "update_from_vmdb - #{err.to_s}"
        #   _log.error err.backtrace.join("\n")
        # end
        # _log.info "update_from_vmdb end"

        @updateLock.synchronize(:EX) do
          _log.info "cleanup start"
          begin
            MiqSmisAgent.cleanup
          rescue => err
            _log.error "cleanup - #{err}"
            $log.error err.backtrace.join("\n")
          end
          _log.info "cleanup end"
        end

        break if @exiting
      end
      _log.info "smis_update_thread exiting"
    end
  end

  def start_status_update_thread
    return if @exiting

    _log.info "starting status_update_thread"
    @status_update_thread = Thread.new do
      loop do
        begin
          @flagLock.sync_lock(:EX)
          @status_update_in_progress  = false

          unless @status_update_requested
            @flagLock.sync_unlock
            _log.info "STATUS sleeping #{@status_update_period}"
            slept = 0
            while slept < @status_update_period do
              sv = sleep @status_update_period
              if @status_update_requested
                @flagLock.sync_lock(:EX)
                @status_update_requested = false
                break
              end
              slept += sv
            end
          else
            @status_update_requested = false
          end

          break if @exiting
          @status_update_in_progress  = true
        ensure
          @flagLock.sync_unlock if @flagLock.sync_locked?
        end

        @updateLock.synchronize(:SH) do
          _log.info "STATUS update start"
          begin
            MiqSmisAgent.update_status
          rescue => err
            _log.error "STATUS - #{err}"
            $log.error err.backtrace.join("\n")
          end
          _log.info "STATUS update end"
        end
        break if @exiting
      end
      _log.info "status_update_thread exiting"
    end
  end

  def start_stats_update_thread
    return if @exiting

    _log.info "starting stats_update_thread"
    @stats_update_thread = Thread.new do
      loop do
        _log.info "STATS sleeping #{@stats_update_period}"
        sleep @stats_update_period
        break if @exiting

        @updateLock.synchronize(:SH) do
          _log.info "STATS update start"
          begin
            MiqSmisAgent.update_stats
          rescue => err
            _log.error "STATS - #{err}"
            $log.error err.backtrace.join("\n")
          end
          _log.info "STATS update end"
        end
        break if @exiting
      end
      _log.info "stats_update_thread exiting"
    end
  end

  def do_work
    # All the work is done in threads
  end

  def do_heartbeat_work
    if @smis_update_thread && !@smis_update_thread.alive?
      _log.info "restarting smis_update_thread"
      start_smis_update_thread # this will start all 3 if needed
      return
    end

    if @status_update_thread && !@status_update_thread.alive?
      _log.info "restarting status_update_thread"
      start_status_update_thread
    end

    if @stats_update_thread && !@stats_update_thread.alive?
      _log.info "restarting stats_update_thread"
      start_stats_update_thread
    end
  end

  def message_request_smis_update(*args)
    _log.info "."
    @flagLock.synchronize(:EX) do
      return if @smis_update_in_progress || @smis_update_requested
      @smis_update_requested = true
    end
    @smis_update_thread.run if @smis_update_thread && @smis_update_thread.alive? # in case @smis_update_thread is sleeping.
    #
    # if the thread is not alive the update will take place when it's restarted by do_heartbeat_work.
    #
  end

  def message_request_status_update(*args)
    _log.info "."
    @flagLock.synchronize(:EX) do
      return if @smis_update_in_progress || @smis_update_requested  # Includes status information.
      return if @status_update_in_progress || @status_update_requested
      @status_update_requested = true
    end
    @status_update_thread.run if @status_update_thread && @status_update_thread.alive? # in case @status_update_thread is sleeping.
    #
    # if the thread is not alive the update will take place when it's restarted by do_heartbeat_work.
    #
  end

  def before_exit(message, exit_code)
    _log.info "exiting: #{message} (#{exit_code})"
    @exiting = true
    @smis_update_thread.run   while @smis_update_thread && @smis_update_thread.alive?
    @status_update_thread.run while @status_update_thread && @status_update_thread.alive?
    @stats_update_thread.run  while @stats_update_thread  && @stats_update_thread.alive?
  end
end
