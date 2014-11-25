require 'sync'
require_relative '../SyncDebug'

$stdout.sync = true

$my_puts_mutex = Mutex.new
def my_puts(str="")
  $my_puts_mutex.synchronize { puts str }
end

def lock_timeout_test(lock, mode, sleep_secs)
  begin
    my_puts "**** #{Thread.current.object_id}: Acquiring lock..."
    lock.synchronize(mode) do
      my_puts "**** #{Thread.current.object_id}: sleeping for #{sleep_secs} seconds."
      sleep sleep_secs
    end
    my_puts "**** #{Thread.current.object_id}: Released lock."
  rescue => t1err
    my_puts "**** (from rescue) #{Thread.current.object_id}: #{t1err}"
  end
end

def dead_locker_test(lock, mode)
  my_puts "**** #{Thread.current.object_id}: Acquiring lock..."
  lock.lock(mode)
  my_puts "**** #{Thread.current.object_id}: Exiting."
  Thread.exit
end

begin

  sync_dbg = Sync.new
  sync_dbg.extend(SyncDebug_m)
  
  sync_dbg.max_locked_time      = 30
  sync_dbg.watchdog_poll_period = 15
  sync_dbg.lock_name            = "test_lock"

  sync_dbg.on_lock_request do |li|
    my_puts "Requesting lock: #{li[:lock].lock_name}, from_mode = #{li[:lock].sync_mode}, to_mode = #{li[:mode]} [#{li[:call_stack][0]}]"
  end
  sync_dbg.on_lock_acquire do |li|
    my_puts "Acquired lock: #{li[:lock].lock_name}, acquired_mode = #{li[:lock].sync_mode}, requested_mode = #{li[:mode]} [#{li[:call_stack][0]}]"
  end

  sync_dbg.on_unlock_request do |li|
    my_puts "Releasing lock: #{li[:lock].lock_name}, pre-release_mode = #{li[:lock].sync_mode}, [#{li[:call_stack][0]}]"
  end
  sync_dbg.on_unlock do |li|
    my_puts "Released lock: #{li[:lock].lock_name}, post-release_mode = #{li[:lock].sync_mode}, [#{li[:call_stack][0]}]"
  end

  sync_dbg.on_dead_locker do |lia|
    li  = lia.first
    thr = li[:thread]
    ln  = li[:lock].lock_name
    Thread.main.raise SyncDebug_m::DeadLockerException.new(ln, thr)
  end

  # pass a lambda as an arg.
  sync_dbg.on_lock_timeout lambda { |li, dt|
    thr = li[:thread]
    my_puts "Lock timeout (from callback): thread #{thr.object_id} has held #{li[:lock].lock_name} for #{dt} seconds"
    my_puts "Lock acquisition: Start backtrace"
    my_puts li[:call_stack].join("\n")
    my_puts "Lock acquisition: End backtrace"

    my_puts "Locking thread: Start backtrace"
    my_puts thr.backtrace.join("\n") if thr.alive?
    my_puts "Locking thread: End backtrace"
    return true # raise exception
  }

  sync_dbg.on_watchdog_start do |lock|
    my_puts "Watchdog starting for #{lock.lock_name}"
  end

  sync_dbg.on_watchdog_stop do |lock, err|
    my_puts "Watchdog for #{lock.lock_name} stopping"
    if err
      my_puts "Watchdog ERROR: #{err}"
      my_puts "Watchdog: Start backtrace"
      my_puts err.backtrace.join("\n")
      my_puts "Watchdog: End backtrace"
    end
  end

  sync_dbg.on_watchdog_heartbeat do |lock|
    my_puts "Watchdog for #{lock.lock_name}: HEARTBEAT"
  end

  sync_dbg.on_watchdog_acquire_mutex do |lock|
    my_puts "Watchdog for #{lock.lock_name}: MUTEX acquired"
  end

  sync_dbg.on_watchdog_release_mutex do |lock|
    my_puts "Watchdog for #{lock.lock_name}: MUTEX released"
  end

  sync_dbg.watchdog_enabled = true
  sleep 2

  my_puts
  my_puts "TEST 1: mode = EX, no timeout."
  my_puts
  my_puts "Creating test_thread..."
  test_thread = Thread.new(sync_dbg, :EX, sync_dbg.max_locked_time/2) { |l, m, ss| lock_timeout_test(l, m, ss) }
  my_puts "Waiting for test_thread..."
  test_thread.join
  my_puts "Done."

  sleep 30

  my_puts
  my_puts "TEST 2: mode = SH, no timeout."
  my_puts
  my_puts "Creating test_thread..."
  test_thread = Thread.new(sync_dbg, :SH, sync_dbg.max_locked_time/2) { |l, m, ss| lock_timeout_test(l, m, ss) }
  my_puts "Waiting for test_thread..."
  test_thread.join
  my_puts "Done."

  my_puts
  my_puts "TEST 3: mode = EX, w/timeout."
  my_puts
  my_puts "Creating test_thread..."
  test_thread = Thread.new(sync_dbg, :EX, sync_dbg.max_locked_time * 4) { |l, m, ss| lock_timeout_test(l, m, ss) }
  my_puts "Waiting for test_thread..."
  test_thread.join
  my_puts "Done."

  my_puts
  my_puts "TEST 4: mode = SH, w/timeout."
  my_puts
  my_puts "Creating test_thread..."
  test_thread = Thread.new(sync_dbg, :SH, sync_dbg.max_locked_time * 4) { |l, m, ss| lock_timeout_test(l, m, ss) }
  my_puts "Waiting for test_thread..."
  test_thread.join
  my_puts "Done."

  mode = :SH
  my_puts
  my_puts "TEST 5: mode = #{mode}, dead locker."
  my_puts
  my_puts "Creating test_thread..."
  begin
    test_thread = Thread.new(sync_dbg, mode) { |l, m| dead_locker_test(l, m) }
    my_puts "Waiting for test_thread..."
    test_thread.join
    sleep sync_dbg.watchdog_poll_period * 3
  rescue => dlerr
    my_puts "Dead locker rescue (#{mode}): #{dlerr}"
  end
  my_puts "Done."

  # my_puts
  # my_puts "TEST 6: mode = SH, dead locker."
  # my_puts
  # my_puts "Creating test_thread..."
  # begin
  #   test_thread = Thread.new(sync_dbg, :SH) { |l, m| dead_locker_test(l, m) }
  #   my_puts "Waiting for test_thread..."
  #   test_thread.join
  #   sleep sync_dbg.watchdog_poll_period * 3
  # rescue => dlerr
  #   my_puts "Dead locker rescue (SH): #{dlerr.to_s}"
  # end
  # my_puts "Done."

rescue => err

  my_puts err.to_s
  my_puts err.backtrace.join("\n")

end
