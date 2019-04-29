require 'pg'
require 'pg/logical_replication'

class MiqPglogical
  include Vmdb::Logging

  PUBLICATION_NAME = 'miq'.freeze
  ALWAYS_EXCLUDED_TABLES = %w(ar_internal_metadata schema_migrations repl_events repl_monitor repl_nodes).freeze

  attr_reader :configured_excludes

  def initialize
    @pg_connection = ApplicationRecord.connection.raw_connection
    self.configured_excludes = provider? ? active_excludes : self.class.default_excludes
  end

  delegate :subscriber?, :to => :pglogical

  # Sets the tables that should be used to create the publication using refresh_excludes
  def configured_excludes=(new_excludes)
    @configured_excludes = new_excludes | ALWAYS_EXCLUDED_TABLES
  end

  # Returns the excluded tables that are currently being used
  # @return Array<String> the table list
  def active_excludes
    return [] unless provider?
    ApplicationRecord.connection.tables - included_tables
  end

  def provider?
    pglogical.publishes?(PUBLICATION_NAME)
  end

  def configure_provider
    return if provider?
    create_replication_set
  end

  def destroy_provider
    return unless provider?
    pglogical.drop_publication(PUBLICATION_NAME)
  end

  # Lists the tables currently being replicated
  # @return Array<String> the table list
  def included_tables
    pglogical.tables_in_publication(PUBLICATION_NAME)
  end

  # Creates the 'miq' publication and refreshes the excluded tables
  def create_replication_set
    pglogical.create_publication(PUBLICATION_NAME)
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

  # Aligns the contents of the 'miq' publication with the currently configured excludes
  def refresh_excludes
    tables = ApplicationRecord.connection.tables - configured_excludes
    pglogical.set_publication_tables(PUBLICATION_NAME, tables)
  end

  def replication_lag
    pglogical.lag_bytes
  end

  def replication_wal_retained
    pglogical.wal_retained_bytes
  end

  def self.default_excludes
    YAML.load_file(Rails.root.join("config/default_replication_exclude_tables.yml"))[:exclude_tables] | ALWAYS_EXCLUDED_TABLES
  end

  def self.save_remote_region(exclusion_list)
    # part of `MiqRegion.replication_type=` is initialization of default subscription list
    MiqRegion.replication_type = :remote
    # UI is passing empty 'exclution_list' if there are no changes to default subscription list
    refresh_excludes(YAML.safe_load(exclusion_list)) unless exclusion_list.empty?
  end

  def self.save_global_region(subscriptions_to_save, subscriptions_to_remove)
    MiqRegion.replication_type = :global
    PglogicalSubscription.delete_all(subscriptions_to_remove)
    PglogicalSubscription.save_all!(subscriptions_to_save)
  end

  private

  def pglogical(refresh = false)
    @pglogical = nil if refresh
    @pglogical ||= PG::LogicalReplication::Client.new(@pg_connection)
  end
end
