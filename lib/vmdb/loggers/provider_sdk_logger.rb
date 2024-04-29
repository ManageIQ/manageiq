module Vmdb::Loggers
  class ProviderSdkLogger < ManageIQ::Loggers::Base
    def initialize(*_, **_)
      super

      # pulled from Ruby's `Logger::Formatter`, which is what it defaults to when it is `nil`
      @datetime_format = "%Y-%m-%dT%H:%M:%S.%6N "
      @formatter = Formatter.new
    end

    def <<(msg)
      msg = msg.strip
      log(level, msg)
      msg.size
    end

    class Formatter < ManageIQ::Loggers::Base::Formatter
      def call(severity, datetime, progname, msg)
        msg = msg.sub(/Bearer(.*?)"/, 'Bearer [FILTERED] "')
        msg = msg.sub(/SharedKey(.*?)"/, 'SharedKey [FILTERED] "')
        msg = msg.sub(/client_secret=(.*?)&/, "client_secret=[FILTERED]&")
        msg = msg.sub(/apikey=(.*?)"/, 'apikey=[FILTERED]"')
        super(severity, datetime, progname, msg)
      end
    end
  end
end
