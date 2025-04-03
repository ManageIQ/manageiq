module Vmdb::Loggers
  class RequestLogger < ManageIQ::Loggers::Base
    attr_reader :resource_id

    def initialize(*args, resource_id:, **kwargs)
      @resource_id = resource_id
      super(nil, *args, **kwargs)
    end

    def add(severity, message = nil, progname = nil)
      severity ||= Logger::UNKNOWN
      if resource_id.nil? or severity < level
        return true
      end
      if progname.nil?
        progname = @progname
      end
      if message.nil?
        if block_given?
          message = yield
        else
          message = progname
          progname = @progname
        end
      end

      RequestLog.create(:message => message, :severity => format_severity(severity), :resource_id => resource_id)

      true
    end
  end
end
