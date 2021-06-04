module ArPglogicalMigrationHelper
  SCHEMA_MIGRATIONS_RAN_MIGRATION = "20171031010000".freeze
  def self.schema_migrations_ran_exists?(version)
    # Schema versions less than 20171031010000 certainly don't have the table, so we can
    # avoid excessive queries but since this method is called both before AND after a migration
    # from the ArPglogicalMigration prepended module, 20171031010000 is different based on direction:
    #   migrate up   - before: missing, after: exists
    #   migrate down - before: exists,  after: missing
    # Therefore, we need to query the table for that migration.
    return false if version < SCHEMA_MIGRATIONS_RAN_MIGRATION
    return false if version == SCHEMA_MIGRATIONS_RAN_MIGRATION && !ActiveRecord::Base.connection.table_exists?("schema_migrations_ran")
    true
  end

  def self.discover_schema_migrations_ran_class(version)
    return unless schema_migrations_ran_exists?(version)

    Class.new(ActiveRecord::Base) do
      require 'active_record-id_regions'
      include ActiveRecord::IdRegions
      self.table_name = "schema_migrations_ran"
      default_scope { in_my_region }
    end
  end

  def self.update_local_migrations_ran(version, direction)
    return unless schema_migrations_ran_exists?(version)

    if direction == :up
      if version == SCHEMA_MIGRATIONS_RAN_MIGRATION
        to_add = ActiveRecord::SchemaMigration.normalized_versions << version
        puts "Seeding :schema_migrations_ran table..."
      else
        to_add = [version]
      end

      to_add.each do |v|
        ActiveRecord::Base.connection.execute("INSERT INTO schema_migrations_ran (version, created_at) VALUES ('#{v}', '#{Time.now.utc.iso8601}')")
      end
    else
      ActiveRecord::Base.connection.execute("DELETE FROM schema_migrations_ran WHERE version = '#{version}'")
    end
  end

  class RemoteRegionMigrationWatcher
    class SubscriptionHelper < ActiveRecord::Base; end

    attr_reader :subscription, :version, :schema_migrations_ran_class

    def initialize(subscription, version)
      @schema_migrations_ran_class = ArPglogicalMigrationHelper.discover_schema_migrations_ran_class(version)
      @subscription                = subscription
      @version                     = version
    end

    def wait_for_remote_region_migration(wait_time = 1)
      return unless wait_for_migration?

      Vmdb.rails_logger.info(wait_message)
      print(wait_message)

      while wait_for_migration?
        print(".")
        restart_subscription
        sleep(wait_time)
      end

      puts("\n")
    end

    private

    def region_number
      subscription.provider_region
    end

    def wait_for_migration?
      return false unless schema_migrations_ran_class
      # We need to unscope here since in_region doesn't override the default scope of in_my_region
      # see https://github.com/ManageIQ/activerecord-id_regions/issues/11
      !schema_migrations_ran_class.unscoped.in_region(region_number).where(:version => version).exists?
    end

    def wait_message
      @wait_message ||= "Waiting for remote region #{region_number} to run migration #{version}"
    end

    def restart_subscription
      c = SubscriptionHelper.establish_connection.connection.raw_connection
      rep_client = PG::LogicalReplication::Client.new(c)

      rep_client.disable_subscription(subscription.id)
      rep_client.enable_subscription(subscription.id)
    ensure
      SubscriptionHelper.remove_connection
    end
  end
end

module ArPglogicalMigration
  def migrate(direction)
    PglogicalSubscription.all.each do |s|
      ArPglogicalMigrationHelper::RemoteRegionMigrationWatcher.new(s, version.to_s).wait_for_remote_region_migration
    end
    ret = super
    ArPglogicalMigrationHelper.update_local_migrations_ran(version.to_s, direction)
    ret
  end
end

ActiveRecord::Migration.prepend(ArPglogicalMigration)
