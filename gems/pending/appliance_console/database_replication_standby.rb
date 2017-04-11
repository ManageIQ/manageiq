require 'appliance_console/logging'
require 'appliance_console/prompts'
require 'appliance_console/database_replication'
require "appliance_console/logical_volume_management"
require 'util/postgres_admin'
require 'fileutils'
require 'linux_admin'

module ApplianceConsole
  class DatabaseReplicationStandby < DatabaseReplication
    include ApplianceConsole::Logging

    REGISTER_CMD    = 'repmgr standby register'.freeze
    REPMGRD_SERVICE = 'rh-postgresql95-repmgr'.freeze

    attr_accessor :disk, :standby_host, :run_repmgrd_configuration

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
      self.disk = ask_for_disk("Standby database disk")
      ask_for_unique_cluster_node_number
      ask_for_database_credentials
      ask_for_standby_host
      ask_for_repmgrd_configuration
      return false if repmgr_configured? && !confirm_reconfiguration
      confirm
    end

    def confirm
      super
      say(<<-EOS) if disk
        Database Disk:              #{disk.path}
      EOS
      say(<<-EOS)
        Standby Host:               #{standby_host}
        Automatic Failover:         #{run_repmgrd_configuration ? "enabled" : "disabled"}
      EOS
      agree("Apply this Replication Server Configuration? (Y/N): ")
    end

    def ask_for_standby_host
      self.standby_host = ask_for_ip_or_hostname("Standby Server hostname or IP address", standby_host)
    end

    def ask_for_repmgrd_configuration
      self.run_repmgrd_configuration = ask_yn?("Configure Replication Manager (repmgrd) for automatic failover")
    end

    def activate
      say("Configuring Replication Standby Server...")
      initialize_postgresql_disk if disk
      PostgresAdmin.prep_data_directory
      data_dir_empty? &&
        generate_cluster_name &&
        create_config_file(standby_host) &&
        clone_standby_server &&
        start_postgres &&
        register_standby_server &&
        write_pgpass_file &&
        (run_repmgrd_configuration ? start_repmgrd : true)
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

    def start_repmgrd
      LinuxAdmin::Service.new(REPMGRD_SERVICE).enable.start
      true
    rescue AwesomeSpawn::CommandResultError => e
      message = "Failed to start repmgrd: #{e.message}"
      Logging.logger.error(message)
      say(message)
      false
    end

    private

    def initialize_postgresql_disk
      log_and_feedback(__method__) do
        LogicalVolumeManagement.new(:disk                => disk,
                                    :mount_point         => PostgresAdmin.mount_point,
                                    :name                => "pg",
                                    :volume_group_name   => PostgresAdmin.volume_group_name,
                                    :filesystem_type     => PostgresAdmin.database_disk_filesystem,
                                    :logical_volume_path => PostgresAdmin.logical_volume_path).setup
      end
    end
  end # class DatabaseReplicationStandby < DatabaseReplication
end # module ApplianceConsole
