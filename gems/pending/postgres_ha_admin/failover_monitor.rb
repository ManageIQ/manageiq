require 'postgres_ha_admin/failover_databases'
require 'postgres_ha_admin/database_yml'
require 'util/postgres_admin'
require 'pg'
require 'linux_admin'

module PostgresHaAdmin
  class FailoverMonitor
    FAILOVER_ATTEMPTS = 10
    DB_CONNECTED_CHECK_FREQUENCY = 300
    FAILOVER_CHECK_FREQUENCY = 60

    def initialize(db_yml_file = '/var/www/miq/vmdb/config/database.yml',
                   failover_yml_file = '/var/www/miq/vmdb/config/failover_databases.yml',
                   log_file = '/var/www/miq/vmdb/log/ha_admin.log',
                   environment = 'production')
      @logger = Logger.new(log_file)
      @logger.level = Logger::INFO
      @database_yml = DatabaseYml.new(db_yml_file, environment)
      @failover_db = FailoverDatabases.new(failover_yml_file, @logger)
    end

    def monitor
      connection = pg_connection(@database_yml.pg_params_from_database_yml)
      if connection
        @failover_db.update_failover_yml(connection)
        connection.finish
        return
      end

      @logger.error("Primary Database is not available. EVM server stop initiated. Starting to execute failover...")
      stop_evmserverd

      if execute_failover
        start_evmserverd
      else
        @logger.error("Failover failed")
      end
    end

    def monitor_loop
      loop do
        sleep(DB_CONNECTED_CHECK_FREQUENCY)
        begin
          monitor
        rescue StandardError => err
          @logger.error("#{err.class}: #{err}")
          @logger.error(err.backtrace.join("\n"))
        end
      end
    end

    def active_servers_conninfo
      servers = @failover_db.active_databases_conninfo_hash
      db_yml_params = @database_yml.pg_params_from_database_yml
      servers.map! { |info| db_yml_params.merge(info) }
    end

    private

    def execute_failover
      FAILOVER_ATTEMPTS.times do
        with_each_standby_connection do |connection, params|
          next if PostgresAdmin.database_in_recovery?(connection)
          next unless @failover_db.host_is_repmgr_primary?(params[:host], connection)
          @logger.info("Failing over to server using conninfo: #{params.reject { |k, _v| k == :password }}")
          @failover_db.update_failover_yml(connection)
          @database_yml.update_database_yml(params)
          return true
        end
        sleep(FAILOVER_CHECK_FREQUENCY)
      end
      false
    end

    def with_each_standby_connection
      active_servers_conninfo.each do |params|
        connection = pg_connection(params)
        next if connection.nil?
        begin
          yield connection, params
        ensure
          connection.finish
        end
      end
    end

    def pg_connection(params)
      PG::Connection.open(params)
    rescue PG::Error => e
      @logger.error("Failed to establish PG connection: #{e.message}")
      nil
    end

    def start_evmserverd
      LinuxAdmin::Service.new("evmserverd").restart
      @logger.info("Starting EVM server from failover monitor")
    end

    def stop_evmserverd
      LinuxAdmin::Service.new("evmserverd").stop
    end
  end
end
