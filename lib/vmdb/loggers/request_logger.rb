module Vmdb::Loggers
  class RequestLogger < ManageIQ::Loggers::Base
    attr_reader :log_wrapper

    def initialize(*args, log_wrapper:, **kwargs)
      @log_wrapper = log_wrapper
      super(*args, **kwargs)
    end

    private def add_to_db(severity, message = nil, progname = nil, resource_id: nil)
      return [severity, message, progname] unless resource_id

      # Adapted from Logger#add
      severity ||= UNKNOWN
      if severity < level
        return [severity, message, progname]
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

      RequestLog.create(:message => message, :severity => format_severity(severity), :resource_id => resource_id) if resource_id

      [severity, message, progname]
    end

    def info(progname = nil, resource_id: nil, &block)
      severity, message, progname = add_to_db(INFO, nil, progname, resource_id: resource_id, &block)
      log_wrapper.add(severity, message, progname, &block)
      add(severity, message, progname, &block)
    end

    def debug(progname = nil, resource_id: nil, &block)
      severity, message, progname = add_to_db(DEBUG, nil, progname, resource_id: resource_id, &block)
      log_wrapper.add(severity, message, progname, &block)
      add(severity, message, progname, &block)
    end

    def warn(progname = nil, resource_id: nil, &block)
      severity, message, progname = add_to_db(WARN, nil, progname, resource_id: resource_id, &block)
      log_wrapper.add(severity, message, progname, &block)
      add(severity, message, progname, &block)
    end

    def error(progname = nil, resource_id: nil, &block)
      severity, message, progname = add_to_db(ERROR, nil, progname, resource_id: resource_id, &block)
      log_wrapper.add(severity, message, progname, &block)
      add(severity, message, progname, &block)
    end

    def fatal(progname = nil, resource_id: nil, &block)
      severity, message, progname = add_to_db(FATAL, nil, progname, resource_id: resource_id, &block)
      log_wrapper.add(severity, message, progname, &block)
      add(severity, message, progname, &block)
    end

    def unknown(progname = nil, resource_id: nil, &block)
      severity, message, progname = add_to_db(UNKNOWN, nil, progname, resource_id: resource_id, &block)
      log_wrapper.add(severity, message, progname, &block)
      add(severity, message, progname, &block)
    end
  end
end
