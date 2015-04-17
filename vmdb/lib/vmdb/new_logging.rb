module Vmdb
  class LogProxy < Struct.new(:klass, :separator)
    LEVELS = [:debug, :info, :warn, :error]

    LEVELS.each do |level|
      define_method(level) do |msg|
        Vmdb.logger.send(level, "#{prefix caller_locations(1, 1)} #{msg}")
      end
    end

    def prefix(location = caller_locations(1, 1))
      location = location.first if location.kind_of?(Array)
      meth = location.base_label
      meth = meth ? "#{klass}#{separator}#{meth}" : klass.to_s
      "MIQ(#{meth})"
    end

    def log_backtrace(err)
      Vmdb.logger.log_backtrace(err)
    end
  end

  module NewLogging
    def _log
      self.class.instance_logger
    end
  end

  module ClassLogging
    def instance_logger
      @instance_logger ||= LogProxy.new(self, '#')
    end

    def _log
      @_log ||= LogProxy.new(self, '.')
    end
  end

  ::Module.send :include, ClassLogging
end
