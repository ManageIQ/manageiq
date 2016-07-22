require 'drb'
module MiqAeEngine
  class DrbRemoteInvoker
    attr_accessor :num_methods

    def initialize(workspace)
      @workspace = workspace
      @num_methods = 0
    end

    def with_server
      setup if num_methods == 0
      self.num_methods += 1

      svc = MiqAeMethodService::MiqAeService.new(@workspace)
      yield
    ensure
      svc.destroy # Reset inputs to empty to avoid storing object references
      self.num_methods -= 1
      teardown if num_methods == 0
    end

    def drb_uri
      DRb.uri
    end

    private

    def setup
      require 'drb/timeridconv'
      @@global_id_conv = DRb.install_id_conv(DRb::TimerIdConv.new(drb_cache_timeout))
      drb_front  = MiqAeMethodService::MiqAeServiceFront.new
      drb        = DRb.start_service("druby://127.0.0.1:0", drb_front)
    end

    def teardown
      DRb.stop_service
      # Set the ID conv to nil so that the cache can be GC'ed
      DRb.install_id_conv(nil)
      # This hack was done to prevent ruby from leaking the
      # TimerIdConv thread.
      # https://bugs.ruby-lang.org/issues/12342
      thread = @@global_id_conv
               .try(:instance_variable_get, '@holder')
               .try(:instance_variable_get, '@keeper')
      @@global_id_conv = nil
      return unless thread

      thread.kill
      Thread.pass while thread.alive?
    end

    def drb_cache_timeout
      1.hour
    end
  end
end
