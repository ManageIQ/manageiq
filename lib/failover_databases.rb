class FailoverDatabases
  FAILOVER_DATABASES_YAML_FILE = Rails.root.join("config", "failover_databases.yml").freeze

  def self.refresh_databases_list
    query_repmgr
  end

  def self.all_databases
    if File.exist?(FAILOVER_DATABASES_YAML_FILE)
      begin
        YAML.load_file(FAILOVER_DATABASES_YAML_FILE)
      rescue IOError => err
        _log.error("#{err.class}: #{err}")
        _log.error(err.backtrace.join("\n"))
        []
      end
    else
      query_repmgr
    end
  end

  def self.standby_databases
    all_databases.select { |record| record[:type] == 'standby' }
  end

  def self.active_standby_databases
    all_databases.select { |record| record[:type] == 'standby' && record[:active] == true }
  end

  def self.query_repmgr
    connection = ApplicationRecord.connection
    result = []
    if connection.table_exists? "repmgr_miq.repl_nodes"
      connection.execute("SELECT type, conninfo, active FROM repmgr_miq.repl_nodes").each do |record|
        dsn = connection.class.parse_dsn(record.delete("conninfo"))
        result << record.symbolize_keys.merge(dsn)
      end
      write_file(result)
    end
    result
  end
  private_class_method :query_repmgr

  def self.write_file(result)
    File.write(FAILOVER_DATABASES_YAML_FILE, result.to_yaml)
  rescue IOError => err
    _log.error("#{err.class}: #{err}")
    _log.error(err.backtrace.join("\n"))
    raise
  end
  private_class_method :write_file
end
