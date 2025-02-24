module Vmdb
  module Initializer
    def self.init
      _log.info("Initializing Application: Program Name: #{$PROGRAM_NAME}, PID: #{Process.pid}, ENV['EVMSERVER']: #{ENV['EVMSERVER']}")
      check_db_connectable if perform_db_connectable_check?

      # UiWorker called in Development Mode
      #   * command line(rails server)
      #   * debugger
      if defined?(Rails::Server)
        MiqUiWorker.preload_for_worker_role
        MiqServer.my_server.starting_server_record
        MiqServer.my_server.update(:status => "started")
      end
    end

    def self.init_secret_token
      return if Rails.application.config.secret_key_base

      token = if ActiveRecord::Base.connectable? && MiqDatabase.table_exists? && MiqDatabase.any?
        MiqDatabase.first.session_secret_token
      else
        SecureRandom.hex(64)
      end

      Rails.application.config.secret_key_base = token
    end

    private_class_method def self.log_db_connectable
      _log.info("Successfully connected to the database.")
    end

    private_class_method def self.log_db_not_connectable
      msg = "Cannot connect to the database!"
      _log.error(msg)
      if $stderr.tty?
        yellow_warn_bookends = ["\e[33m** ", "\e[0m"]
        warn(yellow_warn_bookends.join(msg))
      else
        warn(msg)
      end
    end

    private_class_method def self.check_db_connectable
      ActiveRecord::Base.connectable? ? log_db_connectable : log_db_not_connectable
    end

    private_class_method def self.perform_db_connectable_check?
      ENV["PERFORM_DB_CONNECTABLE_CHECK"].to_s.downcase != "false"
    end
  end
end
