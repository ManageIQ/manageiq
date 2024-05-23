require 'pg'
require 'pg/logical_replication'

class MiqPglogical
  include Vmdb::Logging
  include ConnectionHandling

  PUBLICATION_NAME = 'miq'.freeze
  ALWAYS_EXCLUDED_TABLES = %w[ar_internal_metadata schema_migrations repl_events repl_monitor repl_nodes].freeze

  # :nodoc:
  #
  # Note:  Don't use a delegate with this method, since we want the
  # .with_connection_error_handling to wrap this methods
  def subscriber?
    # From: https://www.postgresql.org/docs/10/catalog-pg-subscription.html
    # "Unlike most system catalogs, pg_subscription is shared across all databases of a cluster:
    # There is only one copy of pg_subscription per cluster, not one per database."
    #
    # pglogical.subscriber? defaults to seeing ALL subscriptions in the cluster:
    #
    #   This is confusing if the publisher and subscriber db are in the same cluster such as in dev:
    #     On publisher:  pglogical.subscriber? => true (unexpected)
    #     On subscriber: pglogical.subscriber? => true (expected)
    #
    # Therefore, pass the database_name to ensure only subscrptions created in database_name count for subscriber?
    self.class.with_connection_error_handling { pglogical.subscriber?(self.class.database_name) }
  end

  def provider?
    self.class.with_connection_error_handling { pglogical.publishes?(PUBLICATION_NAME) }
  end

  def configure_provider
    return if provider?

    create_replication_set
  end

  def destroy_provider
    return unless provider?

    self.class.with_connection_error_handling { pglogical.drop_publication(PUBLICATION_NAME) }
  end

  # Lists the tables currently being replicated
  # @return Array<String> the table list
  def included_tables
    self.class.with_connection_error_handling { pglogical.tables_in_publication(PUBLICATION_NAME) }
  end

  # Creates the 'miq' publication and refreshes the excluded tables
  def create_replication_set
    self.class.with_connection_error_handling { pglogical.create_publication(PUBLICATION_NAME) }
    refresh_excludes
  end

  # Aligns the contents of the 'miq' publication with the excludes file
  def refresh_excludes
    self.class.with_connection_error_handling do
      tables = ApplicationRecord.connection.tables - excludes
      pglogical.set_publication_tables(PUBLICATION_NAME, tables)
    end
  end

  def replication_lag
    self.class.with_connection_error_handling { pglogical.lag_bytes }
  end

  def replication_type
    if provider?
      :remote
    elsif subscriber?
      :global
    else
      :none
    end
  end

  def replication_type=(desired_type)
    return unless PglogicalSubscription.logical_replication_supported?

    current_type = replication_type
    destroy_provider if current_type == :remote
    PglogicalSubscription.delete_all if current_type == :global
    configure_provider if desired_type == :remote

    # When adding a global (desired_type == :global), we do nothing here
  end

  def replication_wal_retained
    self.class.with_connection_error_handling { pglogical.wal_retained_bytes }
  end

  def excludes
    self.class.excludes
  end

  def self.excludes
    YAML.load_file(Rails.root.join("config/replication_exclude_tables.yml"))[:exclude_tables] | ALWAYS_EXCLUDED_TABLES
  end

  def self.save_global_region(subscriptions_to_save, subscriptions_to_remove)
    MiqRegion.replication_type = :global
    PglogicalSubscription.delete_all(subscriptions_to_remove)
    PglogicalSubscription.save_all!(subscriptions_to_save)
  end

  def self.database_name
    pg_connection.db
  end

  def self.pg_connection
    ApplicationRecord.connection.raw_connection
  end
  private_class_method :pg_connection
end
