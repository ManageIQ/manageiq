class PgLogicalRaw
  attr_accessor :connection

  # @param connection [PostgreSQLAdapter] ActiveRecord database connection
  def initialize(connection)
    @connection = connection
  end

  def installed?
    connection.select_value("SELECT EXISTS(SELECT * FROM pg_available_extensions WHERE name = 'pglogical')")
  end

  # Returns whether pglogical is currently enabled or not
  #
  # @return [Boolean]
  def enabled?
    return false unless installed? && connection.extension_enabled?("pglogical")
    return true if connection.postgresql_version >= 90_500
    connection.extension_enabled?("pglogical_origin")
  end

  # Enables pglogical postgres extensions
  def enable
    connection.enable_extension("pglogical_origin") if connection.postgresql_version < 90_500
    connection.enable_extension("pglogical")
  end

  def disable
    connection.disable_extension("pglogical")
    connection.disable_extension("pglogical_origin") if connection.postgresql_version < 90_500
  end

  # Monitoring
  #

  # Reports on replication lag from provider to subscriber nodes
  # This method must be run on the provider node
  #
  # @return [Array<Hash<String,String>>] List of returned lag and application names,
  #   one for each replication process
  def lag_bytes
    typed_exec(<<-SQL).to_a
      SELECT
        pg_xlog_location_diff(pg_current_xlog_insert_location(), flush_location) AS lag_bytes,
        application_name
      FROM pg_stat_replication
    SQL
  end

  # Reports on replication bytes of WAL being retained for each replication slot
  # This method must be run on the provider node
  #
  # @return [Array<Hash<String,String>>] List of returned WAL bytes and replication slot names,
  #   one for each replication process
  def wal_retained_bytes
    typed_exec(<<-SQL).to_a
      SELECT
        pg_xlog_location_diff(pg_current_xlog_insert_location(), restart_lsn) AS retained_bytes,
        slot_name
      FROM pg_replication_slots
      WHERE plugin = 'pglogical_output'
    SQL
  end

  # Node Management
  #

  # Creates a node
  #
  # @param name [String]
  # @param dsn [String] external connection string to the node
  def node_create(name, dsn)
    typed_exec("SELECT pglogical.create_node($1, $2)", name, dsn)
  end

  # Updates a node connection string
  #
  # @param name [String]
  # @param dsn [String] new external connection string to the node
  # @return [Boolean] true if the dsn was updated, false otherwise
  #
  # NOTE: This method relies on the internals of the pglogical tables
  #       rather than a published API.
  # NOTE: Disable subscriptions involving the node before
  #       calling this method for a provider node in a subscriber
  #       database.
  def node_dsn_update(name, dsn)
    res = typed_exec(<<-SQL, name, dsn)
      UPDATE pglogical.node_interface
      SET if_dsn = $2
      WHERE if_nodeid = (
        SELECT node_id
        FROM pglogical.node
        WHERE node_name = $1
      )
    SQL

    res.cmd_tuples == 1
  end

  # Drops the node
  #
  # @param name [String]
  # @param ifexists [Boolean]
  def node_drop(name, ifexists = false)
    typed_exec("SELECT pglogical.drop_node($1, $2)", name, ifexists)
  end

  def nodes
    typed_exec(<<-SQL)
      SELECT node_name AS name, if_dsn AS conn_string
      FROM pglogical.node join pglogical.node_interface
        ON if_nodeid = node_id
    SQL
  end

  # Subscription Management
  #

  # Creates a subscription to a provider node
  #
  # @param name [String] subscription name
  # @param dsn [String] provider node connection string
  # @param replication_sets [Array<String>] replication set names to subscribe to
  # @param sync_structure [Boolean] sync the schema structure when subscribing
  # @param sync_data [Boolean] sync the data when subscribing
  # @param forward_origins [Array<String>] names of non-provider nodes to replicate changes from (cascading replication)
  def subscription_create(name, dsn, replication_sets = %w(default default_insert_only),
                          sync_structure = true, sync_data = true, forward_origins = ["all"])
    command = "SELECT pglogical.create_subscription($1, $2, $3, $4, $5, $6)"
    typed_exec(command, name, dsn, replication_sets, sync_structure, sync_data, forward_origins)
  end

  # Disconnects the subscription and removes it
  #
  # @param name [String] subscription name
  # @param ifexists [Boolean] if true an error is not thrown when the subscription does not exist
  def subscription_drop(name, ifexists = false)
    typed_exec("SELECT pglogical.drop_subscription($1, $2)", name, ifexists)
  end

  # Disables a subscription and disconnects it from the provider
  #
  # @param name [String] subscription name
  # @param immediate [Boolean] do not wait for the current transaction before stopping
  def subscription_disable(name, immediate = false)
    typed_exec("SELECT pglogical.alter_subscription_disable($1, $2)", name, immediate)
  end

  # Enables a previously disabled subscription
  #
  # @param name [String] subscription name
  # @param immediate [Boolean] do not wait for the current transaction before starting
  def subscription_enable(name, immediate = false)
    typed_exec("SELECT pglogical.alter_subscription_enable($1, $2)", name, immediate)
  end

  # Syncs all unsynchronized tables in all sets in a single operation.
  #   Command does not block
  #
  # @param name [String] subscription name
  # @param truncate [Boolean] truncate the tables before syncing
  def subscription_sync(name, truncate = false)
    typed_exec("SELECT pglogical.alter_subscription_synchronize($1, $2)", name, truncate)
  end

  # Resyncs one existing table
  # Table will be truncated before the sync
  #
  # @param name [String] subscription name
  # @param table [String] name of the table to resync
  def subscription_resync_table(name, table)
    typed_exec("SELECT pglogical.alter_subscription_resynchronize_table($1, $2)", name, table)
  end

  # Adds a replication set to a subscription
  # Does not sync, only activates event consumption
  #
  # @param name [String] subscription name
  # @param set_name [String] replication set name
  def subscription_add_replication_set(name, set_name)
    typed_exec("SELECT pglogical.alter_subscription_add_replication_set($1, $2)", name, set_name)
  end

  # Removes a replication set from a subscription
  #
  # @param name [String] subscription name
  # @param set_name [String] replication set name
  def subscription_remove_replication_set(name, set_name)
    typed_exec("SELECT pglogical.alter_subscription_remove_replication_set($1, $2)", name, set_name)
  end

  # Shows status and basic information about a subscription
  #
  # @prarm name [String] subscription name
  # @return a hash with the subscription information
  #   keys:
  #     subscription_name
  #     status
  #     provider_node
  #     provider_dsn
  #     slot_name
  #     replication_sets
  #     forward_origins
  def subscription_show_status(name)
    res = typed_exec("SELECT * FROM pglogical.show_subscription_status($1)", name).first
    res["replication_sets"] = res["replication_sets"][1..-2].split(",")
    res["forward_origins"] = res["forward_origins"][1..-2].split(",")
    res
  end

  # Shows the status of all configured subscriptions
  #
  # @return Array<Hash> list of results from #subscription_show_status
  def subscriptions
    ret = []
    connection.select_values("SELECT sub_name FROM pglogical.subscription").each do |s|
      ret << subscription_show_status(s)
    end
    ret
  end

  # Replication Sets
  #

  # Lists the current replication sets
  #
  # @return [Array<String>] the replication sets
  def replication_sets
    typed_exec("SELECT set_name FROM pglogical.replication_set").values.flatten
  end

  # Creates a new replication set
  #
  # @param set_name [String] new replication set name
  # @param insert [Boolean] replicate INSERT events
  # @param update [Boolean] replicate UPDATE events
  # @param delete [Boolean] replicate DELETE events
  # @param truncate [Boolean] replicate TRUNCATE events
  def replication_set_create(set_name, insert = true, update = true, delete = true, truncate = true)
    typed_exec("SELECT pglogical.create_replication_set($1, $2, $3, $4, $5)",
               set_name, insert, update, delete, truncate)
  end

  # Alters an existing replication set
  #
  # @param set_name [String] replication set name
  # @param insert [Boolean] replicate INSERT events
  # @param update [Boolean] replicate UPDATE events
  # @param delete [Boolean] replicate DELETE events
  # @param truncate [Boolean] replicate TRUNCATE events
  def replication_set_alter(set_name, insert = true, update = true, delete = true, truncate = true)
    typed_exec("SELECT pglogical.alter_replication_set($1, $2, $3, $4, $5)",
               set_name, insert, update, delete, truncate)
  end

  # Removes a replication set
  #
  # @param set_name [string] replication set name
  def replication_set_drop(set_name)
    typed_exec("SELECT pglogical.drop_replication_set($1)", set_name)
  end

  # Adds a table to a replication set
  #
  # @param set_name [String] replication set name
  # @param table_name [String] table name to add
  # @param sync [Boolean] sync the table on all subscribers to the given replication set
  def replication_set_add_table(set_name, table_name, sync = false)
    typed_exec("SELECT pglogical.replication_set_add_table($1, $2, $3)", set_name, table_name, sync)
  end

  # Adds all tables in the given schemas to the replication set
  #
  # @param set_name [String] replication set name
  # @param schema_names [Array<String>] list of schema names
  # @param sync [Boolean] sync table data to all the subscribers to the replication set
  def replication_set_add_all_tables(set_name, schema_names, sync = false)
    typed_exec("SELECT pglogical.replication_set_add_all_tables($1, $2, $3)",
               set_name, schema_names, sync)
  end

  # Removes a table from a replication set
  #
  # @param set_name [String] replication set name
  # @param table_name [String] table to remove
  def replication_set_remove_table(set_name, table_name)
    typed_exec("SELECT pglogical.replication_set_remove_table($1, $2)", set_name, table_name)
  end

  # Lists the tables currently in the replication set
  #
  # @param set_name [String] replication set name
  # @return [Array<String>] names of the tables in the given set
  def tables_in_replication_set(set_name)
    typed_exec(<<-SQL, set_name).values.flatten
      SELECT set_reloid
      FROM pglogical.replication_set_relation
      JOIN pglogical.replication_set
        USING (set_id)
      WHERE set_name = $1
    SQL
  end

  def with_replication_set_lock(set_name)
    connection.transaction(:requires_new => true) do
      typed_exec(<<-SQL, set_name)
        SELECT *
        FROM pglogical.replication_set
        WHERE set_name = $1
        FOR UPDATE
      SQL
      yield
    end
  end

  private

  def typed_exec(sql, *params)
    connection.raw_connection.async_exec(sql, params, nil, PG::BasicTypeMapForQueries.new(connection.raw_connection))
  end
end
