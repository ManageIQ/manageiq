require_relative "../util/SyncDebug"

module VimSyncDebug
  def self.extended(obj)
    lock = obj.cacheLock
 
    lock.extend(SyncDebug_m)
    lock.lock_name = "cacheLock(#{obj.connId})"

    lock.on_lock_request do |li|
      $vim_log.info "VimSyncDebug - Requesting lock: #{li[:lock].lock_name}, from_mode = #{li[:lock].sync_mode}, to_mode = #{li[:mode]} [#{li[:call_stack][0]}]"
    end
    lock.on_lock_acquire do |li|
      $vim_log.info "VimSyncDebug - Acquired lock: #{li[:lock].lock_name}, acquired_mode = #{li[:lock].sync_mode}, requested_mode = #{li[:mode].to_s} [#{li[:call_stack][0]}]"
    end

    lock.on_unlock_request do |li|
      $vim_log.info "VimSyncDebug - Releasing lock: #{li[:lock].lock_name}, pre-release_mode = #{li[:lock].sync_mode}, [#{li[:call_stack][0]}]"
    end
    lock.on_unlock do |li|
      $vim_log.info "VimSyncDebug - Released lock: #{li[:lock].lock_name}, post-release_mode = #{li[:lock].sync_mode}, [#{li[:call_stack][0]}]"
    end

    lock.on_dead_locker do |lia|
      li  = lia.first
      thr = li[:thread]
      ln  = li[:lock].lock_name
      $vim_log.error "VimSyncDebug - Locking Thread has terminated: Lock(#{ln}), Thread(#{thr.object_id})."
      $vim_log.error "VimSyncDebug - Start backtrace"
      $vim_log.error li[:call_stack].join("\n")
      $vim_log.error "VimSyncDebug - End backtrace"
    end

    lock.on_lock_timeout lambda { |li, dt|
      thr = li[:thread]
      $vim_log.error "VimSyncDebug - Lock timeout: thread #{thr.object_id} has held #{li[:lock].lock_name} for #{dt} seconds"
      $vim_log.error "VimSyncDebug - Lock acquisition: Start backtrace"
      $vim_log.error li[:call_stack].join("\n")
      $vim_log.error "VimSyncDebug - Lock acquisition: End backtrace"

      $vim_log.error "VimSyncDebug - Locking thread: Start backtrace"
      $vim_log.error thr.backtrace.join("\n") if thr.alive?
      $vim_log.error "VimSyncDebug - Locking thread: End backtrace"
      return false # don't raise an exception
    }

    lock.on_watchdog_start do |lock|
      $vim_log.info "VimSyncDebug - Watchdog starting for #{lock.lock_name}"
    end

    lock.on_watchdog_stop do |lock, err|
      $vim_log.info "VimSyncDebug - Watchdog for #{lock.lock_name} stopping"
      if err
        $vim_log.error "VimSyncDebug - Watchdog ERROR: #{err.to_s}"
        $vim_log.error "VimSyncDebug - Watchdog: Start backtrace"
        $vim_log.error err.backtrace.join("\n")
        $vim_log.error "VimSyncDebug - Watchdog: End backtrace"
      end
    end

    lock.on_watchdog_heartbeat do |lock|
      $vim_log.debug "Watchdog for #{lock.lock_name}: HEARTBEAT"
    end

    # lock.on_watchdog_acquire_mutex do |lock|
    #   $vim_log.debug "Watchdog for #{lock.lock_name}: MUTEX acquired"
    # end

    # lock.on_watchdog_release_mutex do |lock|
    #   $vim_log.debug "Watchdog for #{lock.lock_name}: MUTEX released"
    # end

    lock.watchdog_enabled = true
  end
end
