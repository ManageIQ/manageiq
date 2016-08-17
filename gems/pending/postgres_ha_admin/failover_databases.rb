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

    def active_databases_conninfo_hash
      valid_keys = PG::Connection.conndefaults_hash.keys + [:requiressl]
      active_databases.map! do |db_info|
        db_info.keep_if { |k, _v| valid_keys.include?(k) }
      end
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

    def host_is_repmgr_primary?(host, connection)
      query_repmgr(connection).each do |record|
        if record[:host] == host && entry_is_active_master?(record)
          return true
        end
      end
      false
    end

    private

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

    def entry_is_active_master?(record)
      record[:type] == 'master' && record[:active]
    end

    def all_databases
      return [] unless File.exist?(yml_file)
      YAML.load_file(yml_file)
    end

    def table_exists?(connection, table_name)
      result = connection.exec("SELECT to_regclass('#{table_name}')").first
      !result['to_regclass'].nil?
    end
  end
end
