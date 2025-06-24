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
      # base will be generated from local file in a different format if nil
      base = Rails.application.config.secret_key_base
      db_token = session_secret_token

      # skip if base is already set to db_token
      return if base == db_token

      new_token = if db_token.present?
        # use db_token above all
        db_token
      else
        # generate a new token if base isn't already configured
        return if base.match(/^\h{128}$/)
        SecureRandom.hex(64)
      end

      Rails.application.config.secret_key_base = new_token
    end

    private_class_method def self.session_secret_token
      return nil unless ActiveRecord::Base.connectable?
      return nil unless MiqDatabase.table_exists?
      return nil unless MiqDatabase.any?

      begin
        MiqDatabase.first.session_secret_token
      rescue ManageIQ::Password::PasswordError => err
        log_error_and_tty_aware_warn("#{err.class.name}: '#{err.message}' trying to read the session_secret_token!")
        log_error_and_tty_aware_warn("Did you just restore or change databases? This happens when you use a v2_key that doesn't match the one used for the source database.")
        log_error_and_tty_aware_warn("Try tools/fix_auth.rb or clearing the session_secret_token in the miq_databases table.")
        nil
      end
    end

    private_class_method def self.log_db_connectable
      _log.info("Successfully connected to the database.")
    end

    private_class_method def self.log_error_and_tty_aware_warn(msg)
      _log.error(msg)
      if $stderr.tty?
        yellow_warn_bookends = ["\e[33m** ", "\e[0m"]
        warn(yellow_warn_bookends.join(msg))
      else
        warn(msg)
      end
    end

    private_class_method def self.check_db_connectable
      ActiveRecord::Base.connectable? ? log_db_connectable : log_error_and_tty_aware_warn("Cannot connect to the database!")
    end

    private_class_method def self.perform_db_connectable_check?
      ENV["PERFORM_DB_CONNECTABLE_CHECK"].to_s.downcase != "false"
    end
  end
end
