module Vmdb
  module Initializer
    def self.init
      _log.info("- Program Name: #{$PROGRAM_NAME}, PID: #{Process.pid}, ENV['EVMSERVER']: #{ENV['EVMSERVER']}")

      # UiWorker called in Development Mode
      #   * command line(rails server)
      #   * debugger
      if defined?(Rails::Server)
        MiqUiWorker.preload_for_worker_role
        MiqServer.my_server.starting_server_record
        MiqServer.my_server.update(:status => "started")
      end

      # Rails console needs session store configured
      if defined?(Rails::Console)
        MiqUiWorker.preload_for_console
      end
    end
  end
end
