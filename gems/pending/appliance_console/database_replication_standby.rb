require 'appliance_console/logging'
require 'appliance_console/prompts'
require 'appliance_console/database_replication'
require 'util/postgres_admin'

module ApplianceConsole
  class DatabaseReplicationStandby < DatabaseReplication
    include ApplianceConsole::Logging

    REGISTER_CMD = 'repmgr standby register'.freeze

    def initialize
      self.cluster_name      = nil
      self.node_number       = nil
      self.database_name     = "vmdb_production"
      self.database_user     = "root"
      self.database_password = nil
      self.primary_host      = nil
      self.standby_host      = LinuxAdmin::NetworkInterface.new(NETWORK_INTERFACE).address
    end

    def ask_questions
      clear_screen
      say("Establish Replication Standby Server\n")
      ask_for_unique_cluster_node_number
      ask_for_database_credentials
      ask_for_standby_host
      return false if repmgr_configured? && !confirm_reconfiguration
      confirm(:including_standby_host)
    end

    def ask_for_standby_host
      self.standby_host = ask_for_ip_or_hostname("Standby Server hostname or IP address", standby_host)
    end

    def activate
      say("Configuring Replication Standby Server...")
      data_dir_empty? &&
        generate_cluster_name &&
        create_config_file(standby_host) &&
        clone_standby_server &&
        start_postgres &&
        register_standby_server
    end

    def data_dir_empty?
      return true if Dir[PostgresAdmin.data_directory.join("*")].empty?
      Logging.logger.info("Appliance database found under: #{PostgresAdmin.data_directory}")
      say("")
      say("Appliance database found under: #{PostgresAdmin.data_directory}")
      say("Replication standby server can not be configured if the database already exists")
      say("Remove the existing database before configuring as a standby server")
      say("")
      false
    end

    def clone_standby_server
      params = { :h  => primary_host,
                 :U  => database_user,
                 :d  => database_name,
                 :D  => PostgresAdmin.data_directory,
                 nil => %w(standby clone)
               }
      run_repmgr_command("repmgr", params)
    end

    def start_postgres
      LinuxAdmin::Service.new(PostgresAdmin.service_name).enable.start
      true
    end

    def register_standby_server
      run_repmgr_command(REGISTER_CMD)
    end
  end # class DatabaseReplicationStandby < DatabaseReplication
end # module ApplianceConsole
