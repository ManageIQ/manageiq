module Vmdb::Loggers
  class AuditLogger < ManageIQ::Loggers::Base
    def success(msg)
      info("<AuditSuccess> #{msg}")
    end

    def failure(msg)
      warn("<AuditFailure> #{msg}")
    end
  end
end
