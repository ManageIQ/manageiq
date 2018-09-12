require 'pg'
require 'pg/pglogical'
require 'pg/pglogical/active_record_extension'

class MiqPglogical
  include Vmdb::Logging

  REPLICATION_SET_NAME = 'miq'.freeze
  NODE_PREFIX = "region_".freeze
  ALWAYS_EXCLUDED_TABLES = %w(ar_internal_metadata schema_migrations repl_events repl_monitor repl_nodes).freeze

  attr_reader :configured_excludes

  def initialize
    @connection = ApplicationRecord.connection
    self.configured_excludes = provider? ? active_excludes : self.class.default_excludes
  end

  # Sets the tables that should be used to create the replication set using refresh_excludes
  def configured_excludes=(new_excludes)
    @configured_excludes = new_excludes | ALWAYS_EXCLUDED_TABLES
  end

  # Returns the excluded tables that are currently being used by pglogical
  # @return Array<String> the table list
  def active_excludes
    return [] unless provider?
    @connection.tables - included_tables
  end

  # Returns whether or not this server is configured as a provider node
  # @return Boolean
  def provider?
    pglogical.enabled? && pglogical.replication_sets.include?(REPLICATION_SET_NAME)
  end

  # Returns whether or not this server is configured as a subscriber node
  # @return Boolean
  def subscriber?
    pglogical.enabled? && !pglogical.subscriptions.empty?
  end

  # Returns whether or not this server is a pglogical node
  def node?
    pglogical.enabled? && pglogical.nodes.field_values("name").include?(self.class.local_node_name)
  end

  # Creates a pglogical node using the rails connection
  def create_node
    pglogical.node_create(self.class.local_node_name, connection_dsn)
  end

  # Drops the pglogical node associated with this connection
  def drop_node
    pglogical.node_drop(self.class.local_node_name, true)
  end

  # Configures the database as a pglogical replication source
  #   This includes enabling the extension, creating the
  #   node and creating the replication set
  def configure_provider
    return if provider?
    @connection.transaction(:requires_new => true) do
      pglogical.enable
      create_node unless node?
      create_replication_set
    end
  end

  # Removes the replication configuration and pglogical node from the
  # database
  def destroy_provider
    return unless provider?
    pglogical.replication_set_drop(REPLICATION_SET_NAME)
    drop_node
    pglogical.disable
  end

  # Lists the tables currently being replicated by pglogical
  # @return Array<String> the table list
  def included_tables
    pglogical.tables_in_replication_set(REPLICATION_SET_NAME)
  end

  # Creates the 'miq' replication set and refreshes the excluded tables
  def create_replication_set
    pglogical.replication_set_create(REPLICATION_SET_NAME)
    refresh_excludes
  end

  def self.refresh_excludes_queue(new_excludes)
    MiqQueue.put(
      :class_name  => "MiqPglogical",
      :method_name => "refresh_excludes",
      :args        => [new_excludes]
    )
  end

  def self.refresh_excludes(new_excludes)
    pgl = new
    pgl.configured_excludes = new_excludes
    pgl.refresh_excludes
  end

  # Aligns the contents of the 'miq' replication set with the currently configured vmdb excludes
  def refresh_excludes
    pglogical.with_replication_set_lock(REPLICATION_SET_NAME) do
      # remove newly excluded tables from replication set
      newly_excluded_tables.each do |table|
        _log.info("Removing #{table} from #{REPLICATION_SET_NAME} replication set")
        pglogical.replication_set_remove_table(REPLICATION_SET_NAME, table)
      end

      # add tables to the set which are no longer excluded (or new)
      newly_included_tables.each do |table|
        _log.info("Adding #{table} to #{REPLICATION_SET_NAME} replication set")
        pglogical.replication_set_add_table(REPLICATION_SET_NAME, table, true)
      end
    end
  end

  def replication_lag
    pglogical.lag_bytes
  end

  def replication_wal_retained
    pglogical.wal_retained_bytes
  end

  def self.local_node_name
    region_to_node_name(MiqRegion.my_region_number)
  end

  def self.region_to_node_name(region_id)
    "#{NODE_PREFIX}#{region_id}"
  end

  def self.node_name_to_region(name)
    name.sub(NODE_PREFIX, "").to_i
  end

  def self.default_excludes
    YAML.load_file(Rails.root.join("config/default_replication_exclude_tables.yml"))[:exclude_tables] | ALWAYS_EXCLUDED_TABLES
  end

  def self.save_remote_region(exclusion_list)
    MiqRegion.replication_type = :remote
    refresh_excludes(YAML.safe_load(exclusion_list))
  end

  def self.save_global_region(subscriptions_to_save, subscriptions_to_remove)
    MiqRegion.replication_type = :global
    PglogicalSubscription.delete_all(subscriptions_to_remove)
    PglogicalSubscription.save_all!(subscriptions_to_save)
  end

  private

  def pglogical(refresh = false)
    @pglogical = nil if refresh
    @pglogical ||= @connection.pglogical
  end

  def connection_dsn
    config = @connection.raw_connection.conninfo_hash.delete_blanks
    PG::Connection.parse_connect_args(config)
  end

  # tables that are currently included, but we want them excluded
  def newly_excluded_tables
    included_tables & configured_excludes
  end

  # tables that are currently excluded, but we want them included
  def newly_included_tables
    (@connection.tables - configured_excludes) - included_tables
  end
end
