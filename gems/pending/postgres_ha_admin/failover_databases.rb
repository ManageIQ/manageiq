require 'pg'
require 'pg/dsn_parser'

module PostgresHaAdmin
  class FailoverDatabases
    TABLE_NAME = "repl_nodes".freeze

    attr_reader :yml_file

    def initialize(yml_file, logger)
      @yml_file = yml_file
      @logger = logger
    end

    def active_databases
      all_databases.select { |record| record[:active] }
    end

    def update_failover_yml(connection)
      arr_yml = query_repmgr(connection)
      File.write(yml_file, arr_yml.to_yaml) unless arr_yml.empty?
    rescue IOError => err
      @logger.error("#{err.class}: #{err}")
      @logger.error(err.backtrace.join("\n"))
    end

    private

    def all_databases
      return [] unless File.exist?(yml_file)
      YAML.load_file(yml_file)
    end

    def query_repmgr(connection)
      return [] unless table_exists?(connection, TABLE_NAME)
      result = []
      db_result = connection.exec("SELECT type, conninfo, active FROM #{TABLE_NAME}")
      db_result.map_types!(PG::BasicTypeMapForResults.new(connection)).each do |record|
        dsn = PG::DSNParser.parse(record.delete("conninfo"))
        result << record.symbolize_keys.merge(dsn)
      end
      db_result.clear
      result
    rescue PG::Error => err
      @logger.error("#{err.class}: #{err}")
      @logger.error(err.backtrace.join("\n"))
      result
    end

    def table_exists?(connection, table_name)
      result = connection.exec("SELECT to_regclass('#{table_name}')").first
      !result['to_regclass'].nil?
    end
  end
end
