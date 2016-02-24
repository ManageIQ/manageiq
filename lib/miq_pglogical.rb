class MiqPglogical
  REPLICATION_SET_NAME = 'miq'
  SETTINGS_PATH = [:workers, :worker_base, :replication_worker, :replication]

  def initialize(connection = ApplicationRecord.connection)
    @connection = connection
  end

  # Lists the tables currently being replicated by pglogical
  # @return Array<String> the table list
  def included_tables
    pglogical.tables_in_replication_set(REPLICATION_SET_NAME)
  end

  # Lists the tables configured to be excluded in the vmdb configuration
  # @return Array<String> the table list
  def configured_excludes
    settings = YAML.load(@connection.select_value(<<-SQL))
    SELECT settings FROM configurations WHERE typ = 'vmdb'
    SQL
    settings.deep_symbolize_keys.fetch_path(*SETTINGS_PATH, :exclude_tables)
  end

  # Returns whether or not this server is configured as a provider node
  # @return Boolean
  def provider?
    pglogical.installed? && pglogical.enabled? && pglogical.replication_sets.include?(REPLICATION_SET_NAME)
  end

  # Creates a pglogical node using the rails connection
  def create_node
    pglogical.node_create(connection_node_name, connection_dsn)
  end

  # Creates the 'miq' replication set and refreshes the excluded tables
  def create_replication_set
    pglogical.replication_set_create(REPLICATION_SET_NAME)
    refresh_excludes
  end

  # Aligns the contents of the 'miq' replication set with the currently configured vmdb excludes
  def refresh_excludes
    # remove newly excluded tables from replication set
    newly_excluded_tables.each do |table|
      pglogical.replication_set_remove_table(REPLICATION_SET_NAME, table)
    end

    # add tables to the set which are no longer excluded (or new)
    newly_included_tables.each do |table|
      pglogical.replication_set_add_table(REPLICATION_SET_NAME, table)
    end
  end

  private

  def pglogical(refresh = false)
    @pglogical = nil if refresh
    @pglogical ||= @connection.pglogical
  end

  # tables that are currently included, but we want them excluded
  def newly_excluded_tables
    included_tables & configured_excludes
  end

  # tables that are currently excluded, but we want them included
  def newly_included_tables
    (@connection.tables - configured_excludes) - included_tables
  end

  def connection_dsn
    config = @connection.raw_connection.conninfo_hash
    dsn = "dbname=#{config[:dbname]}"
    dsn << " user=#{config[:user]}" if config[:user]
    dsn << " password=#{config[:password]}" if config[:password]
    dsn << " host=#{config[:host]}" if config[:host]
    dsn
  end

  def connection_node_name
    "region_#{db_region_number}"
  end

  def db_region_number
    ApplicationRecord.id_to_region(@connection.select_value("SELECT last_value FROM miq_databases_id_seq"))
  end
end
