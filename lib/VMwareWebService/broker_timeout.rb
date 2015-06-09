#
# Requiring this file replaces Ruby's stdlib Timeout.timeout
# with an implementation that has proper critical section protection.
#
# Background: The implementation of Ruby's Timeout.timeout method
# contains an unprotected critical section that may result in unexpected
# and/or undesired behavior - depending on the client's usage.
# In MIQ, this bug contributed to the issue described here:
#     https://bugzilla.redhat.com/show_bug.cgi?id=1207018
#
# Description: The Timeout.timeout method starts a "timing" thread that
# sleeps for the specified period of time. Once the timing thread is
# started, the parent (timed) thread yields control to the code block - the
# section of code subject to the timeout.
#
# A timeout occurs when the timing thread wakes up before we return from the 
# yield to the code block. Here, the timing thread raises an exception in the
# timed thread, terminating the execution of the code block.
#
# When the code block doesn't timeout, we return from the yield. The parent
# thread then kills the timing thread - supposedly preventing it from waking
# up and raising a timeout exception. I say supposedly, because this is the
# heart of the unprotected critical section. From the time the yield returns,
# until the time the timing thread is killed, the timing thread can still
# wake up and raise an exception in the timed thread. Since the timed thread
# is no longer executing the code block subject to timeout, this can result
# in unpredicted and undesired behavior.
#
# This fix employs a Mutex and state flag to protect this critical section
# of code, preventing this from happening.
#
# TODO: This code is based on the Ruby 2.0 implementation of timeout. When
# upgrading to new versions of Ruby, we need to reevaluate this code against
# the new Ruby implementations.
#
module Timeout
  def timeout(sec, klass = nil)   #:yield: +sec+
    return yield(sec) if sec == nil or sec.zero?
    exception = klass || Class.new(ExitException)
    state_lock = Mutex.new
    state = :sleeping

    begin
      begin
        x = Thread.current
        y = Thread.start {
          begin
            sleep sec
          rescue => e
            state_lock.synchronize do
              if state == :sleeping
                state = :exception
                x.raise e
              end
            end
          else
            state_lock.synchronize do
              if state == :sleeping
                state = :timeout
                x.raise exception, "execution expired"
              end
            end
          end
        }
        rv = yield(sec)
        state_lock.synchronize do
          if state == :sleeping
            state = :returned_from_yield
            return rv
          end
        end
      ensure
        state_lock.synchronize do
          if state == :sleeping || state == :returned_from_yield
            state = :killing
            if y
              y.kill
              y.join # make sure y is dead.
            end
          end
        end
      end
    rescue exception => e
      rej = /\A#{Regexp.quote(__FILE__)}:#{__LINE__-4}\z/o
      (bt = e.backtrace).reject! {|m| rej =~ m}
      level = -caller(CALLER_OFFSET).size
      while THIS_FILE =~ bt[level]
        bt.delete_at(level)
        level += 1
      end
      raise if klass            # if exception class is specified, it
                                # would be expected outside.
      raise Error, e.message, e.backtrace
    end
  end

  module_function :timeout
end
