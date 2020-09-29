module Vmdb::Loggers
  class IbmCloudLogger < VMDBLogger
    def initialize(*loggers)
      super

      # pulled from Ruby's `Logger::Formatter`, which is what it defaults to when it is `nil`
      @datetime_format = "%Y-%m-%dT%H:%M:%S.%6N "
      @formatter       = Vmdb::Loggers::IbmCloudLogger::Formatter.new
    end

    def <<(msg)
      msg = msg.strip
      log(level, msg)
      msg.size
    end

    class Formatter < VMDBLogger::Formatter
      def call(severity, datetime, progname, msg)
        msg = msg.sub(/Bearer(.*?)\"/, 'Bearer [FILTERED] "')
        super(severity, datetime, progname, msg)
      end
    end
  end
end
