class EmsMicrosoft
  module ScvmmErrorHandling
    class ScvmmNotInstalled < RuntimeError; end

    NOT_SCVMM_SVR_ERR = "the specified module 'virtualmachinemanager' was not loaded"
    NOT_SCVMM_SVR_DBG = "SCVMM is not running on this server"

    @scvmm_errors_hash = {
      NOT_SCVMM_SVR_ERR => [ScvmmNotInstalled, NOT_SCVMM_SVR_DBG],
    }

    def self.raise_error_condition(error_str)
      @scvmm_errors_hash.keys.each do |e|
        raise @scvmm_errors_hash[e].first, @scvmm_errors_hash[e].last if error_str.downcase.include? e
      end
    end
  end
end
