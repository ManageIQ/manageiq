require 'postgres_ha_admin/postgres_ha_admin'
require 'pg'
require 'pg/dsn_parser'

module PostgresHaAdmin
  class FailoverDatabases
    TABLE_NAME = "repl_nodes".freeze

    attr_reader :yml_file, :connection_hash, :logger, :log_file

    def initialize(config_dir, log_dir, connection_params_hash)
      @yml_file = Pathname.new(config_dir).join(DB_YML_FILE)
      @log_file = Pathname.new(log_dir).join(LOG_FILE_NAME)
      @logger = Logger.new(@log_file)
      @logger.level = Logger::INFO
      @connection_hash = connection_params_hash
    end

    def refresh_databases_list(connection = nil)
      query_repmgr(connection)
    end

    def all_databases(connection = nil)
      if File.exist?(yml_file)
        begin
          YAML.load_file(yml_file)
        rescue IOError => err
          logger.error("#{err.class}: #{err}")
          logger.error(err.backtrace.join("\n"))
          []
        end
      else
        query_repmgr(connection)
      end
    end

    def standby_databases(connection = nil)
      all_databases(connection).select { |record| record[:type] == 'standby' }
    end

    def active_standby_databases(connection = nil)
      all_databases(connection).select { |record| record[:type] == 'standby' && record[:active] == true }
    end

    private

    def query_repmgr(connection)
      if connection.nil?
        connection = PG::Connection.open(connection_hash)
        new_connection = true
      end

      result = []
      if miq_replication_exists?(connection)
        db_result = connection.exec("SELECT type, conninfo, active FROM #{TABLE_NAME}")
        db_result.map_types!(PG::BasicTypeMapForResults.new(connection)).each do |record|
          dsn = PG::DSNParser.parse(record.delete("conninfo"))
          result << record.symbolize_keys.merge(dsn)
        end
        db_result.clear
        write_file(result)
        logger.info("List standby databases in #{yml_file} replaced.")
      end
      connection.finish if new_connection
      result
    end

    def write_file(result)
      File.write(yml_file, result.to_yaml)
    rescue IOError => err
      logger.error("#{err.class}: #{err}")
      logger.error(err.backtrace.join("\n"))
      raise
    end

    def miq_replication_exists?(connection)
      connection.exec("SELECT to_regclass('#{TABLE_NAME}')")
    end
  end
end
