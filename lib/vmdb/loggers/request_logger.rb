module Vmdb::Loggers
  class RequestLogger < ManageIQ::Loggers::Base
    attr_reader :resource_id

    def initialize(*args, resource_id:, **kwargs)
      super(nil, *args, **kwargs)

      @resource_id = resource_id
      @logdev      = Logdev.new(resource_id) if resource_id
      @formatter   = Formatter.new
    end

    class Formatter
      def call(severity, _time, _progname, msg)
        "#{severity}:#{msg}"
      end
    end
  end
end
