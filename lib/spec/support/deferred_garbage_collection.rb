class DeferredGarbageCollection
  DEFERRED_GC_THRESHOLD = (ENV['DEFER_GC'] || 10.0).to_f

  class << self
    attr_accessor :last_gc_run
  end

  @last_gc_run = Time.now

  def self.start
    GC.disable if DEFERRED_GC_THRESHOLD > 0
  end

  def self.should_run_gc?
    DEFERRED_GC_THRESHOLD > 0 && (Time.now - last_gc_run) >= DEFERRED_GC_THRESHOLD
  end

  def self.reconsider
    if should_run_gc?
      GC.enable
      GC.start
      GC.disable
      self.last_gc_run = Time.now
    end
  end
end
