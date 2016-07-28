require 'util/postgres_dsn_parser'
require 'postgres_ha_admin/postgres_ha_logger'
require 'pg'

module PostgresHaAdmin
  class FailoverDatabases
    include PostgresHaLogger
    include PostgresHaAdmin

    def initialize(config_dir, log_dir, connection_params_hash)
      init_config_dir(config_dir)
      init_logger(log_dir)
      @connection_hash = connection_params_hash
    end

    def refresh_databases_list
      query_repmgr
    end

    def all_databases
      if File.exist?(yml_file)
        begin
          YAML.load_file(yml_file)
        rescue IOError => err
          log_error("#{err.class}: #{err}")
          log_error(err.backtrace.join("\n"))
          []
        end
      else
        query_repmgr
      end
    end

    def standby_databases
      all_databases.select { |record| record[:type] == 'standby' }
    end

    def active_standby_databases
      all_databases.select { |record| record[:type] == 'standby' && record[:active] == true }
    end

    private

    def query_repmgr
      result = []
      connection = PG::Connection.open(connection_hash)
      if table_exists?(connection)
        db_result = connection.exec("SELECT type, conninfo, active FROM repmgr_miq.repl_nodes")
        db_result.map_types!(PG::BasicTypeMapForResults.new(connection)).each do |record|
          dsn = PostgresDsnParser.parse_dsn(record.delete("conninfo"))
          result << record.symbolize_keys.merge(dsn)
        end
        db_result.clear
        write_file(result)
        log_info("List standby databases in #{yml_file} replaced.")
      end
      connection.finish
      result
    end

    def write_file(result)
      File.write(yml_file, result.to_yaml)
    rescue IOError => err
      log_error("#{err.class}: #{err}")
      log_error(err.backtrace.join("\n"))
      raise
    end

    def table_exists?(connection)
      connection.exec("SELECT to_regclass('repmgr_miq.repl_nodes')")
    end
  end
end
