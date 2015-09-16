module Vmdb
  class LogProxy < Struct.new(:klass, :separator)
    class NullLogger < Logger
      def initialize(*)
        super('/dev/null')
        self.level = Logger::UNKNOWN
      end

      def filename(*); end
      def log_backtrace(*); end
      def log_hashes(*); end
      def success(*); end
      def failure(*); end
    end

    def self.null_logger
      @null_logger ||= NullLogger.new
    end

    LEVELS = [:debug, :info, :warn, :error]

    delegate *LEVELS.map { |level| :"#{level}?" },
      :log_backtrace, :level, :to => :logger

    LEVELS.each do |level|
      define_method(level) do |msg = nil, &blk|
        location = caller_locations(1, 1)
        if blk
          logger.send(level) do
            "#{prefix location} #{blk.call}"
          end
        else
          logger.send(level, "#{prefix location} #{msg}")
        end
      end
    end

    def prefix(location = caller_locations(1, 1))
      location = location.first if location.kind_of?(Array)
      meth = location.base_label
      meth = meth ? "#{klass}#{separator}#{meth}" : klass
      "MIQ(#{meth})"
    end

    private

    def logger
      Vmdb.logger || $log || LogProxy.null_logger
    end
  end

  module Logging
    def _log
      self.class.instance_logger
    end
  end

  module ClassLogging
    def instance_logger
      @instance_logger ||= LogProxy.new(name, '#')
    end

    def _log
      @_log ||= LogProxy.new(name, '.')
    end
  end

  ::Module.send :include, ClassLogging
end

require 'vmdb/loggers'
