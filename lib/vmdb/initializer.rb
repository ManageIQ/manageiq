module Vmdb
  module Initializer
    def self.init
      _log.info "- Program Name: #{$PROGRAM_NAME}, PID: #{Process.pid}, ENV['MIQ_GUID']: #{ENV['MIQ_GUID']}, ENV['EVMSERVER']: #{ENV['EVMSERVER']}"

      # When these classes are deserialized in ActiveRecord (e.g. EmsEvent, MiqQueue), they need to be preloaded
      require 'VimTypes'

      # UiWorker called in Development Mode
      #   * command line(rails server)
      #   * debugger
      if defined?(Rails::Server)
        # preload_for_worker_role depends on seeding, principally MiqDatabase
        EvmDatabase.seed_primordial

        MiqUiWorker.preload_for_worker_role
        MiqServer.my_server.starting_server_record
        MiqServer.my_server.update_attributes(:status => "started")
      end

      # Rails console needs session store configured
      if defined?(Rails::Console)
        MiqUiWorker.preload_for_console
      end
    end
  end
end
