module Vmdb::Loggers
  class AuditLogger < ManageIQ::Loggers::Base
    def success(msg)
      msg = "<AuditSuccess> #{msg}"
      info(msg)
      $log.info(msg) if $log
    end

    def failure(msg)
      msg = "<AuditFailure> #{msg}"
      warn(msg)
      $log.warn(msg) if $log
    end
  end
end
