require 'vmdb/loggers'

module Vmdb
  class LogProxy < Struct.new(:klass, :separator, :prefix_cache)
    LEVELS = [:debug, :info, :warn, :error]

    # def debug?
    # def info?
    # def warn?
    # def error?
    # def add
    # def level
    # def log_backtrace
    (LEVELS.map { |l| :"#{l}?" } + %i[add level log_backtrace]).each do |method|
      define_method(method) { |*args| logger.send(method, *args) }
    end

    LEVELS.each do |level|
      define_method(level) do |msg = nil, &blk|
        location = caller_locations(1, 1)
        if blk
          logger.send(level) do
            "#{prefix(location)} #{blk.call}"
          end
        else
          logger.send(level, "#{prefix(location)} #{msg}")
        end
      end
    end

    def prefix(location = caller_locations(1, 1))
      location = location.first if location.kind_of?(Array)
      meth = location.base_label
      prefix_cache[meth] ||= meth ? "MIQ(#{klass}#{separator}#{meth})" : "MIQ(#{klass})"
    end

    private

    def logger
      Vmdb.logger
    end
  end

  module Logging
    def _log
      self.class.instance_logger
    end
  end

  module ClassLogging
    def instance_logger
      @instance_logger ||= LogProxy.new(name, '#', {})
    end

    def _log
      @_log ||= LogProxy.new(name, '.', {})
    end
  end

  ::Module.include ClassLogging
end
