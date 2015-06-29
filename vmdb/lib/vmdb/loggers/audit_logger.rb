module Vmdb::Loggers
  class AuditLogger < VMDBLogger
    def success(msg)
      info("Success") { msg }
      $log.info("<AuditSuccess> #{msg}") if $log
    end

    def failure(msg)
      warn("Failure") { msg }
      $log.warn("<AuditFailure> #{msg}") if $log
    end
  end
end
