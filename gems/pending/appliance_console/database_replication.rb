require 'appliance_console/logging'
require 'appliance_console/prompts'
require 'pg'
require 'English'

module ApplianceConsole
  class DatabaseReplication
    include ApplianceConsole::Logging

    REPMGR_CONFIG = '/etc/repmgr.conf'.freeze

    attr_accessor :cluster_name, :node_number,
                  :database_name, :database_user, :database_password,
                  :primary_host, :standby_host

    def ask_for_unique_cluster_node_number
      self.node_number = ask_for_integer("number uniquely identifying this node in the replication cluster")
    end

    def ask_for_database_credentials
      ask_for_cluster_database_credentials
      self.primary_host = ask_for_ip_or_hostname("primary database hostname or IP address", primary_host)
    end

    def confirm(including_standby_host = nil)
      clear_screen
      say(<<-EOL)
Replication Server Configuration

        Cluster Node Number:        #{node_number}
        Cluster Database Name:      #{database_name}
        Cluster Database User:      #{database_user}
        Cluster Database Password:  "********"
        Cluster Primary Host:       #{primary_host}
        EOL
      say("        Standby Host:               #{standby_host}") unless including_standby_host.nil?

      agree("Apply this Replication Server Configuration? (Y/N): ")
    end

    def repmgr_configured?
      File.exist?(REPMGR_CONFIG)
    end

    def confirm_reconfiguration
      say("Warning: File #{REPMGR_CONFIG} exists. Replication is already configured")
      Logging.logger.warn("Warning: File #{REPMGR_CONFIG} exists. Replication is already configured")
      agree("Continue with configuration? (Y/N): ")
    end

    def create_config_file(host)
      File.open(REPMGR_CONFIG, "w") do |f|
        f.puts("cluster=#{cluster_name}")
        f.puts("node=#{node_number}")
        f.puts("node_name=#{host}")
        f.puts("conninfo='host=#{host} user=#{database_user} dbname=#{database_name}'")
        f.puts("use_replication_slots=1")
        f.puts("pg_basebackup_options='--xlog-method=stream'")
      end
      true
    end

    def generate_cluster_name
      begin
        pg_conn = PG::Connection.new(:dbname   => database_name,
                                     :host     => primary_host,
                                     :user     => database_user,
                                     :password => database_password)
        primary_region_number =
          pg_conn.exec("SELECT last_value FROM miq_databases_id_seq").first["last_value"].to_i / 1_000_000_000_000
        self.cluster_name = "miq_region_#{primary_region_number}_cluster"
      rescue PG::ConnectionBad => e
        say("Failed to get primary region number #{e.message}")
        Logging.logger.error("Failed to get primary region number #{e.message}")
        return false
      end
      true
    end

    private

    def ask_for_cluster_database_credentials
      self.database_name = just_ask("cluster database name", database_name)
      self.database_user = just_ask("cluster database username", database_user)

      count = 0
      loop do
        count += 1
        password1 = ask_for_password_or_none("cluster database password", database_password)
        # if they took the default, just bail
        break if password1 == database_password
        password2 = ask_for_password("cluster database password")
        if password1 == password2
          self.database_password = password1
          break
        elsif count > 1 # only reprompt password once
          raise ArgumentError, "passwords did not match"
        else
          say("\nThe passwords did not match, please try again")
        end
      end
    end

    def run_repmgr_command(cmd, params = {})
      pid = fork do
        Process::UID.change_privilege(Process::UID.from_name("postgres"))
        begin
          res = AwesomeSpawn.run!(cmd, :params => params, :env => {"PGPASSWORD" => database_password})
          say(res.output)
        rescue AwesomeSpawn::CommandResultError => e
          say(e.result.output)
          say(e.result.error)
          say("")
          say("Failed to configure replication server")
          raise
        end
      end

      Process.wait(pid)
      $CHILD_STATUS.success?
    end
  end # class DatabaseReplication < DatabaseConfiguration
end # module ApplianceConsole
