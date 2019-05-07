require 'pg'
require 'pg/logical_replication'

class MiqPglogical
  include Vmdb::Logging

  PUBLICATION_NAME = 'miq'.freeze
  ALWAYS_EXCLUDED_TABLES = %w(ar_internal_metadata schema_migrations repl_events repl_monitor repl_nodes).freeze

  def initialize
    @pg_connection = ApplicationRecord.connection.raw_connection
  end

  delegate :subscriber?, :to => :pglogical

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

  # Aligns the contents of the 'miq' publication with the excludes file
  def refresh_excludes
    tables = ApplicationRecord.connection.tables - excludes
    pglogical.set_publication_tables(PUBLICATION_NAME, tables)
  end

  def replication_lag
    pglogical.lag_bytes
  end

  def replication_wal_retained
    pglogical.wal_retained_bytes
  end

  def excludes
    self.class.excludes
  end

  def self.excludes
    YAML.load_file(Rails.root.join("config", "replication_exclude_tables.yml"))[:exclude_tables] | ALWAYS_EXCLUDED_TABLES
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
