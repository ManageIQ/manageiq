
module SyncDebug_m
  MAX_LOCKED_TIME      = 60 * 5
  WATCHDOG_POLL_PERIOD = 60 * 5

  attr_accessor :lock_name, :max_locked_time, :watchdog_poll_period
  attr_reader   :watchdog_enabled

  #
  # Exceptions.
  #
  class DeadLockerException < StandardError
    def initialize(ln, th)
      # TODO: set backtrace to where lock was acquired.
      super("Lock: #{ln}: Locking Thread(#{th.object_id}) has terminated.")
    end
  end

  class LockTimeoutException < StandardError
    def initialize(li, dt)
      # TODO: set backtrace to where lock was acquired or where the thread is now (or both?).
      super("Lock #{li[:lock].lock_name} timed out after #{dt} seconds: Thread = #{li[:thread].object_id}")
    end
  end

  class SyncDebugBug < StandardError
    def initialize(lock, msg)
      super("#{lock.class.name} [BUG] - #{lock.lock_name}: #{msg}")
    end
  end

  module ClassMethods
    #
    # Class methods to get and set class-wide default values.
    #
    def max_locked_time=(val)
      @max_locked_time = val
    end

    def max_locked_time
      @max_locked_time || MAX_LOCKED_TIME
    end

    def watchdog_poll_period=(val)
      @watchdog_poll_period = val
    end

    def watchdog_poll_period
      @watchdog_poll_period || WATCHDOG_POLL_PERIOD
    end

    def on_try_lock_request(call_back=nil, &block)
      @try_lock_request_callback = SyncDebug_m.proc_or_block(__method__, call_back, block)
    end

    def on_try_lock_return(call_back=nil, &block)
      @try_lock_return_callback = SyncDebug_m.proc_or_block(__method__, call_back, block)
    end

    def on_lock_request(call_back=nil, &block)
      @lock_request_callback = SyncDebug_m.proc_or_block(__method__, call_back, block)
    end

    def on_lock_acquire(call_back=nil, &block)
      @lock_acquire_callback = SyncDebug_m.proc_or_block(__method__, call_back, block)
    end

    def on_unlock_request(call_back=nil, &block)
      @unlock_request_callback = SyncDebug_m.proc_or_block(__method__, call_back, block)
    end

    def on_unlock(call_back=nil, &block)
      @unlock_callback = SyncDebug_m.proc_or_block(__method__, call_back, block)
    end

    def on_dead_locker(call_back=nil, &block)
      @dead_locker_callback = SyncDebug_m.proc_or_block(__method__, call_back, block)
    end

    def on_lock_timeout(call_back=nil, &block)
      @lock_timeout_callback = SyncDebug_m.proc_or_block(__method__, call_back, block)
    end

    def on_watchdog_start(call_back=nil, &block)
      @watchdog_start_callback = SyncDebug_m.proc_or_block(__method__, call_back, block)
    end

    def on_watchdog_stop(call_back=nil, &block)
      @watchdog_stop_callback = SyncDebug_m.proc_or_block(__method__, call_back, block)
    end

    def on_watchdog_heartbeat(call_back=nil, &block)
      @watchdog_heartbeat_callback = SyncDebug_m.proc_or_block(__method__, call_back, block)
    end

    def on_watchdog_acquire_mutex(call_back=nil, &block)
      @watchdog_acquire_mutex_callback = SyncDebug_m.proc_or_block(__method__, call_back, block)
    end

    def on_watchdog_release_mutex(call_back=nil, &block)
      @watchdog_release_mutex_callback = SyncDebug_m.proc_or_block(__method__, call_back, block)
    end

    def try_lock_request_callback;        @try_lock_request_callback;       end
    def try_lock_return_callback;         @try_lock_return_callback;        end
    def lock_request_callback;            @lock_request_callback;           end
    def lock_acquire_callback;            @lock_acquire_callback;           end
    def unlock_request_callback;          @unlock_request_callback;         end
    def unlock_callback;                  @unlock_callback;                 end
    def dead_locker_callback;             @dead_locker_callback;            end
    def lock_timeout_callback;            @lock_timeout_callback;           end
    def watchdog_start_callback;          @watchdog_start_callback;         end
    def watchdog_stop_callback;           @watchdog_stop_callback;          end
    def watchdog_heartbeat_callback;      @watchdog_heartbeat_callback;     end
    def watchdog_acquire_mutex_callback;  @watchdog_acquire_mutex_callback; end
    def watchdog_release_mutex_callback;  @watchdog_release_mutex_callback; end
  end

  def SyncDebug_m.proc_or_block(method_name, call_back, block)
    raise "#{method_name}: method_name arg and block are mutually exclusive." if call_back && block
    return call_back || block
  end

  def SyncDebug_m.included(host_class)
    raise "Sync_m module must be included before SyncDebug_m" unless host_class < Sync_m
    host_class.extend(ClassMethods)
    define_aliases(:module_eval, host_class) unless host_class.instance_of?(Module)
  end

  def SyncDebug_m.extended(host_obj)
    raise "Objects extended by SyncDebug_m must be descendants of Sync_m" unless host_obj.class < Sync_m
    SyncDebug_m.define_aliases(:instance_eval, host_obj)
    SyncDebug_m.init_common(host_obj)
    host_obj.instance_eval %q{
      @max_locked_time      = MAX_LOCKED_TIME
      @watchdog_poll_period = WATCHDOG_POLL_PERIOD
    }
  end

  #
  # Reset aliases to point to our debug stubs.
  #
  def SyncDebug_m.define_aliases(eval_meth, obj)
    obj.send(eval_meth, %q{
      alias lock sync_lock
      alias unlock sync_unlock
      alias try_lock sync_try_lock
    })
  end

  #
  # Instance methods to override class defaults.
  #
  def watchdog_enabled=(val)
    @sync_debug_mutex.synchronize do
      if !(@watchdog_enabled = val) && @watchdog_thread && @watchdog_thread.alive?
        @watchdog_thread.wakeup
      end
    end
    val
  end

  def on_try_lock_request(call_back=nil, &block)
    @try_lock_request_callback = SyncDebug_m.proc_or_block(__method__, call_back, block)
  end

  def on_try_lock_return(call_back=nil, &block)
    @try_lock_return_callback = SyncDebug_m.proc_or_block(__method__, call_back, block)
  end

  def on_lock_request(call_back=nil, &block)
    @lock_request_callback = SyncDebug_m.proc_or_block(__method__, call_back, block)
  end

  def on_lock_acquire(call_back=nil, &block)
    @lock_acquire_callback = SyncDebug_m.proc_or_block(__method__, call_back, block)
  end

  def on_unlock_request(call_back=nil, &block)
    @unlock_request_callback = SyncDebug_m.proc_or_block(__method__, call_back, block)
  end

  def on_unlock(call_back=nil, &block)
    @unlock_callback = SyncDebug_m.proc_or_block(__method__, call_back, block)
  end

  def on_dead_locker(call_back=nil, &block)
    @dead_locker_callback = SyncDebug_m.proc_or_block(__method__, call_back, block)
  end

  def on_lock_timeout(call_back=nil, &block)
    @lock_timeout_callback = SyncDebug_m.proc_or_block(__method__, call_back, block)
  end

  def on_watchdog_start(call_back=nil, &block)
    @watchdog_start_callback = SyncDebug_m.proc_or_block(__method__, call_back, block)
  end

  def on_watchdog_stop(call_back=nil, &block)
    @watchdog_stop_callback = SyncDebug_m.proc_or_block(__method__, call_back, block)
  end

  def on_watchdog_heartbeat(call_back=nil, &block)
    @watchdog_heartbeat_callback = SyncDebug_m.proc_or_block(__method__, call_back, block)
  end

  def on_watchdog_acquire_mutex(call_back=nil, &block)
    @watchdog_acquire_mutex_callback = SyncDebug_m.proc_or_block(__method__, call_back, block)
  end

  def on_watchdog_release_mutex(call_back=nil, &block)
    @watchdog_release_mutex_callback = SyncDebug_m.proc_or_block(__method__, call_back, block)
  end

  #
  # Test stubs, wrapping locking methods.
  #
  def sync_try_lock(m = Sync_m::EX)
    li = locker_info(m)
    fire_on_try_lock_request(li)
    have_lock = super
    if have_lock
      push_lock_info(li)
      check_watchdog
    end
    fire_on_try_lock_return(li, have_lock)
    return have_lock
  end

  def sync_lock(m = Sync_m::EX)
    li = locker_info(m)
    fire_on_lock_request(li)
    rv = super
    push_lock_info(li)
    check_watchdog
    fire_on_lock_acquire(li)
    return rv
  end

  def sync_unlock(m = Sync_m::EX)
    pmode = self.sync_mode
    li = locker_info(pmode)
    fire_on_unlock_request(li)
    rv = super
    pop_lock_info(li)
    fire_on_unlock(li)
    return rv
  end

  private

  def initialize
    super

    #
    # Get default values from class.
    #
    @max_locked_time           = self.class.max_locked_time
    @watchdog_poll_period      = self.class.watchdog_poll_period
    @try_lock_request_callback = self.class.try_lock_request_callback
    @try_lock_return_callback  = self.class.try_lock_return_callback
    @lock_request_callback     = self.class.lock_request_callback
    @lock_acquire_callback     = self.class.lock_acquire_callback
    @unlock_request_callback   = self.class.unlock_request_callback
    @unlock_callback           = self.class.unlock_callback

    SyncDebug_m.init_common(self)
  end

  def SyncDebug_m.init_common(host_obj)
    host_obj.instance_eval %q{
      @sh_locker_info   = Hash.new { |h,k| h[k] = Array.new }
      @ex_locker_info   = []
      @watchdog_thread  = nil
      @sync_debug_mutex = Mutex.new
    }
  end

  #
  # Methods to fire call-back routines.
  #
  def fire_on_try_lock_request(li)
    @try_lock_request_callback.call(li) if @try_lock_request_callback
  end

  def fire_on_try_lock_return(li, rv)
    @try_lock_return_callback.call(li, rv) if @try_lock_return_callback
  end

  def fire_on_lock_request(li)
    @lock_request_callback.call(li) if @lock_request_callback
  end

  def fire_on_lock_acquire(li)
    @lock_acquire_callback.call(li) if @lock_acquire_callback
  end

  def fire_on_unlock_request(li)
    @unlock_request_callback.call(li) if @unlock_request_callback
  end

  def fire_on_unlock(li)
    @unlock_callback.call(li) if @unlock_callback
  end

  def fire_on_watchdog_start(lock)
    @watchdog_start_callback.call(lock) if @watchdog_start_callback
  end

  def fire_on_watchdog_stop(lock, err)
    @watchdog_stop_callback.call(lock, err) if @watchdog_stop_callback
  end

  def fire_on_watchdog_heartbeat(lock)
    @watchdog_heartbeat_callback.call(lock) if @watchdog_heartbeat_callback
  end

  def fire_on_watchdog_acquire_mutex(lock)
    @watchdog_acquire_mutex_callback.call(lock) if @watchdog_acquire_mutex_callback
  end

  def fire_on_watchdog_release_mutex(lock)
    @watchdog_release_mutex_callback.call(lock) if @watchdog_release_mutex_callback
  end

  def fire_on_dead_locker(lia)
    @dead_locker_callback.call(lia) if @dead_locker_callback
  end

  #
  # If there's no callback defined, or the callback returns true,
  # fire_on_lock_timeout will return true. A return value of true
  # will cause the watchdog to raise an exception in the offending
  # thread.
  #
  def fire_on_lock_timeout(li, dt)
    return true unless @lock_timeout_callback
    @lock_timeout_callback.call(li, dt)
  end

  #
  # Bookkeeping to maintain debug info.
  #
  def push_lock_info(li)
    @sync_debug_mutex.synchronize do
      if self.sync_mode == Sync_m::EX
        lia = @ex_locker_info
      elsif self.sync_mode == Sync_m::SH
        lia = @sh_locker_info[Thread.current]
      else
        raise SyncDebugBug.new(self, "push_lock_info: Unexpected lock mode: #{self.sync_mode}")
      end
      lia.push(li)
    end
  end

  def pop_lock_info(li)
    @sync_debug_mutex.synchronize do
      if li[:mode] == Sync_m::EX
        lia = @ex_locker_info
      elsif li[:mode] == Sync_m::SH
        lia = @sh_locker_info[Thread.current]
      else
        raise SyncDebugBug.new(self, "pop_lock_info: Unexpected lock mode: #{li[:mode]}")
      end

      if lia.empty?
        msg = "pop_lock_info: stack underflow, " +
              "pmode = #{li[:mode]}, " +
              "exli# = #{@ex_locker_info.length}, " +
              "shli# = #{@sh_locker_info[Thread.current].length}"
        raise SyncDebugBug.new(self, msg)
      end
      lia.pop
      @sh_locker_info.delete(Thread.current) if lia.empty? && li[:mode] == Sync_m::SH
    end
  end

  #
  # Info maintained per lock acquisition.
  #
  def locker_info(mode)
    {
      :time_stamp => Time.now,
      :lock       => self,
      :mode       => mode,
      :thread     => Thread.current,
      :call_stack => call_stack
    }
  end

  def call_stack
    cs = caller
    cs0 = cs.first
    while cs0["/sync.rb:"] || cs0["/SyncDebug.rb:"]
      cs.shift
      cs0 = cs.first
    end
    return cs
  end

  def check_watchdog
    return unless @watchdog_enabled
    return if @watchdog_thread && @watchdog_thread.alive?

    begin
      @sync_debug_mutex.lock if (unlock = !@sync_debug_mutex.locked?)
      return if @watchdog_thread && @watchdog_thread.alive?
      @watchdog_thread = Thread.new { watchdog }
    ensure
      @sync_debug_mutex.unlock if unlock
    end
  end

  def check_timeout(now_secs, li)
    thr = li[:thread]
    dt = now_secs - li[:time_stamp].to_i
    if dt > @max_locked_time
      if fire_on_lock_timeout(li, dt)
        thr.raise LockTimeoutException.new(li, dt)
        thr.wakeup
      end
    end
  end

  def check_thread(now_secs, thr, lia)
    if thr.alive?
      lia.each { |li| check_timeout(now_secs, li) }
    else
      # XXX Release the thread's locks here? Need support in Sync_m.
      fire_on_dead_locker(lia)
    end
  end

  def watchdog
    fire_on_watchdog_start(self)
    err = nil
    begin
      while @watchdog_enabled
        fire_on_watchdog_heartbeat(self)
        @sync_debug_mutex.synchronize do
          fire_on_watchdog_acquire_mutex(self)
          now_secs = Time.now.to_i
          #
          # TODO: remove dead threads from list, to prevent duplicate notifications.
          #
          hold_count = 0
          unless @ex_locker_info.empty?
            check_thread(now_secs, @ex_locker_info.first[:thread], @ex_locker_info)
            hold_count += 1
          end
          @sh_locker_info.each do |thr, lia|
            check_thread(now_secs, thr, lia)
            hold_count += 1
          end
          #
          # Watchdog only runs while the lock is held.
          #
          if hold_count == 0
            fire_on_watchdog_release_mutex(self)
            Thread.current.exit
          end
        end
        fire_on_watchdog_release_mutex(self)
        sleep @watchdog_poll_period
      end
    rescue Exception => wderr
      err = wderr
    ensure
      fire_on_watchdog_stop(self, err)
    end
  end

end
