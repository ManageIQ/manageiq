require 'appliance_console/logging'
require 'appliance_console/prompts'
require 'appliance_console/database_configuration'
require 'appliance_console/database_replication'

module ApplianceConsole
  class DatabaseReplicationPrimary < DatabaseReplication
    include ApplianceConsole::Logging

    REGISTER_CMD = 'repmgr master register'.freeze

    def initialize
      self.cluster_name      = nil
      self.node_number       = nil
      self.database_name     = "vmdb_production"
      self.database_user     = "root"
      self.database_password = nil
      self.primary_host      = LinuxAdmin::NetworkInterface.new(NETWORK_INTERFACE).address
    end

    def ask_questions
      clear_screen
      say("Establish Primary Replication Server\n")
      ask_for_unique_cluster_node_number
      ask_for_database_credentials
      return false if repmgr_configured? && !confirm_reconfiguration
      confirm
    end

    def confirm
      super
      agree("Apply this Replication Server Configuration? (Y/N): ")
    end

    def activate
      say("Configuring Primary Replication Server...")
      generate_cluster_name &&
        create_config_file(primary_host) &&
        initialize_primary_server
    end

    def initialize_primary_server
      run_repmgr_command(REGISTER_CMD) &&
        add_repmgr_schema_to_search_path
    end

    def add_repmgr_schema_to_search_path
      schema_name = "repmgr_#{cluster_name}"
      begin
        pg_conn = PG::Connection.new(primary_connection_hash)
        new_path = pg_conn.exec("SHOW search_path").first["search_path"].split(",") << schema_name
        pg_conn.exec("ALTER ROLE #{database_user} SET search_path = #{new_path.join(",")}")
      rescue PG::ConnectionBad => e
        say("Failed to add #{schema_name} to search path for #{database_user} #{e.message}")
        Logging.logger.error("Failed to add #{schema_name} to search path for #{database_user} #{e.message}")
        return false
      end
      true
    end
  end # class DatabaseReplicationPrimary < DatabaseReplication
end # module ApplianceConsole
