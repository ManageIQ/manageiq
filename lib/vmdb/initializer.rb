module Vmdb
  module Initializer
    def self.init
      _log.info "- Program Name: #{$PROGRAM_NAME}, PID: #{Process.pid}, ENV['MIQ_GUID']: #{ENV['MIQ_GUID']}, ENV['EVMSERVER']: #{ENV['EVMSERVER']}"

      Vmdb::Loggers.apply_config

      # For `rails server` invocation.  The server calls this before forking UI or Web Service Workers.
      MiqUiWorker.preload if MiqEnvironment::Process.is_ui_worker_via_command_line?

      # When these classes are deserialized in ActiveRecord (e.g. EmsEvent, MiqQueue), they need to be preloaded
      require 'VimTypes'

      ####################################################
      # If UiWorker called in Development Mode
      #   invoked via command line -- script/server
      #   invoked via debugger     -- using rdebug-ide gem
      #
      # Then, set up VMDB as if called from MiqServer:
      #   1. SEED the MUST-HAVE classes
      #   2. Mark current server as started
      #
      ####################################################
      if MiqEnvironment::Process.is_ui_worker_via_command_line?
        EvmDatabase.seed_primordial
        MiqServer.my_server.starting_server_record
        MiqServer.my_server.update_attributes(:status => "started")
      end

      MiqDatabase.seed
      Vmdb::Application.config.secret_token = MiqDatabase.first.session_secret_token
    end
  end
end
