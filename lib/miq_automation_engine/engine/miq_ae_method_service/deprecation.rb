module MiqAeMethodService
  class Deprecation < Vmdb::Deprecation
    def self.default_log
      $miq_ae_logger
    end
  end
end
