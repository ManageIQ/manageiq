require 'benchmark'

module Benchmark

  # Stores the elapsed real time used to execute the given block in the given
  # hash for the given key and returns the result from the block.  If the hash
  # already has a value for that key, the time is accumulated.
  def self.realtime_store(hash, key)
    ret = nil
    r0 = Time.now
    begin
      ret = yield
    ensure
      r1 = Time.now
      hash[key] = (hash[key] || 0) + (r1.to_f - r0.to_f)
    end
    return ret
  end

  # Stores the elapsed real time used to execute the given block for the given
  # key and returns the hash as well as the result from the block.  The hash is
  # stored globally, keyed on thread id, and is cleared once the topmost nested
  # call completes.  If the hash already has a value for that key, the time is
  # accumulated.
  def self.realtime_block(key, &block)
    outermost = !self.in_realtime_block?
    hash = self.current_realtime
    self.current_realtime = hash if outermost

    begin
      ret = self.realtime_store(hash, key, &block)
      return ret, hash
    ensure
      self.delete_current_realtime if outermost
    end    
  end

  def self.in_realtime_block?
    @@realtime_by_tid.has_key?(Thread.current.object_id)
  end

  def self.current_realtime
    @@realtime_by_tid[Thread.current.object_id] || Hash.new(0)
  end
  
  def self.current_realtime=(hash)
    @@realtime_by_tid[Thread.current.object_id] = hash
  end

  def self.delete_current_realtime
    @@realtime_by_tid.delete(Thread.current.object_id)
  end

  @@realtime_by_tid = {}

end
