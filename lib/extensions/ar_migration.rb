module ArPglogicalMigrationHelper
  def self.discover_schema_migrations_ran_class
    return unless ActiveRecord::Base.connection.table_exists?("schema_migrations_ran")
    Class.new(ActiveRecord::Base) do
      require 'active_record-id_regions'
      include ActiveRecord::IdRegions
      self.table_name = "schema_migrations_ran"
      default_scope { in_my_region }
    end
  end

  def self.update_local_migrations_ran(version, direction)
    return unless schema_migrations_ran_class = discover_schema_migrations_ran_class

    new_migrations = ActiveRecord::SchemaMigration.normalized_versions
    new_migrations << version if direction == :up

    to_add = (new_migrations - schema_migrations_ran_class.pluck(:version))
    puts "Seeding :schema_migrations_ran table..." if to_add.size > 1

    to_add.each do |v|
      schema_migrations_ran_class.find_or_create_by(:version => v)
    end

    schema_migrations_ran_class.where(:version => version).delete_all if direction == :down
  end

  class RemoteRegionMigrationWatcher
    class SubscriptionHelper < ActiveRecord::Base; end

    attr_reader :subscription, :version, :schema_migrations_ran_class

    def initialize(subscription, version)
      @schema_migrations_ran_class = ArPglogicalMigrationHelper.discover_schema_migrations_ran_class
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
