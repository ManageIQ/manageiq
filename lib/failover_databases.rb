class FailoverDatabases
  FAILOVER_DATABASES_YAML_FILE = Rails.root.join("config", "failover_databases.yml")

  def self.refresh_databases_list
    query_repmgr
  end

  def self.all_databases
    if File.exist?(FAILOVER_DATABASES_YAML_FILE)
      begin
        YAML.load(File.read(FAILOVER_DATABASES_YAML_FILE))
      rescue => err
        _log.error("#{err.class}: #{err}")
        _log.error(err.backtrace.join("\n"))
        []
      end
    else
      query_repmgr
    end
  end

  def self.standby_databases
    result = []
    all_databases.each do |record|
      result << record if record["type"] == 'standby'
    end
    result
  end

  def self.active_standby_databases
    result = []
    all_databases.each do |record|
      result << record if record["type"] == 'standby' && record["active"] == true
    end
    result
  end

  def self.query_repmgr
    connection = ApplicationRecord.connection
    result = []
    if connection.table_exists? "repmgr_miq.repl_nodes"
      connection.execute("SELECT * FROM repmgr_miq.repl_nodes").each do |data|
        result << data
      end
      write_file(result)
    end
    result
  end
  private_class_method :query_repmgr

  def self.write_file(result)
    File.open(FAILOVER_DATABASES_YAML_FILE, 'w+') do |file|
      file.write(result.to_yaml)
    end
  rescue => err
    _log.error("#{err.class}: #{err}")
    _log.error(err.backtrace.join("\n"))
    raise
  end
  private_class_method :write_file
end
