module Vmdb::Loggers
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

    def add(*args, &block)
      severity = args.first || UNKNOWN
      return true if severity < @level
      loggers.each { |l| l.send(:add, *args, &block) }
      true
    end

    def <<(msg)
      msg = msg.strip
      loggers.each { |l| l.send(:<<, msg) }
      msg.size
    end

    def reopen(_logdev = nil)
      raise NotImplementedError, "#{self.class.name} should not be reopened since it is backed by multiple loggers."
    end

    private

    def method_missing(*args, &block)
      loggers.map { |l| l.send(*args, &block) }.first
    end

    def respond_to_missing?(meth, _)
      loggers.first.respond_to?(meth)
    end
  end
end
