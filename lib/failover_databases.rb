class FailoverDatabases

  FAILOVER_DATABASES_YAML_FILE = Rails.root.join("config", "failover_databases.yaml")

  def self.refresh_databases_list
    query_replication_manager
  end

  def self.all_databases
    if  File.exist?(FAILOVER_DATABASES_YAML_FILE)
      begin
        YAML.load(File.read(FAILOVER_DATABASES_YAML_FILE))
      rescue =>err
        _log.error("#{err.class}: #{err}")
        _log.error(err.backtrace.join("\n"))
        []
      end
    else
      query_replication_manager
    end
  end

  def self.standby_databases
    result = []
    all_databases.each do   |record|
      result << record if record["type"] == 'standby'  
    end
    result
  end

  def self.standby_and_active_databases
    result = []
    all_databases.each do   |record|
      result << record if record["type"] == 'standby' && record["active"] == true
    end
    result
  end

  def self.query_replication_manager
    connection = ApplicationRecord.connection
    return if !(connection.table_exists? "repmgr_miq.repl_nodes")
    result = []
    connection.execute("SELECT * FROM repmgr_miq.repl_nodes").each do |data|
      result << data
    end
    File.open(FAILOVER_DATABASES_YAML_FILE, 'w+') do |file|
      file.write(result.to_yaml)
    end
    result
  rescue => err
    _log.error("#{err.class}: #{err}")
    _log.error(err.backtrace.join("\n"))
  end
  private_class_method :query_replication_manager
end