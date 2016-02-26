class MiqPglogical
  REPLICATION_SET_NAME = 'miq'
  SETTINGS_PATH = [:replication]

  def initialize(connection = ApplicationRecord.connection)
    @connection = connection
  end

  # Returns whether or not this server is configured as a provider node
  # @return Boolean
  def provider?
    pglogical.installed? && pglogical.enabled? && pglogical.replication_sets.include?(REPLICATION_SET_NAME)
  end

  # Returns whether or not this server is configured as a subscriber node
  # @return Boolean
  def subscriber?
    pglogical.installed? && pglogical.enabled? && !pglogical.subscriptions.empty?
  end

  # Creates a pglogical node using the rails connection
  def create_node
    pglogical.node_create(connection_node_name, connection_dsn)
  end

  # Drops the pglogical node associated with this connection
  def drop_node
    pglogical.node_drop(connection_node_name, true)
  end

  private

  def pglogical(refresh = false)
    @pglogical = nil if refresh
    @pglogical ||= @connection.pglogical
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
