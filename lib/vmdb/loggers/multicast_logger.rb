class MulticastLogger < Logger
  attr_accessor :loggers

  def initialize(*loggers)
    require 'set'
    @loggers = Set.new(loggers)
    @level   = DEBUG
  end

  def level=(new_level)
    loggers.each { |l| l.level = new_level }
    super
  end

  def filename
    loggers.first.filename
  end

  [:log_backtrace, :log_hashes].each do |method|
    define_method(method) do |*args|
      loggers.map { |l| l.send(method, *args) }.first
    end
  end

  def add(*args, &block)
    severity = args.first || UNKNOWN
    return true if severity < @level
    loggers.each { |l| l.send(:add, *args, &block) }
    true
  end
end
