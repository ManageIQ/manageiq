module ArPglogicalMigration
  module PglogicalMigrationHelper
    def self.migrations_column_present?
      ActiveRecord::Base.connection.columns("miq_regions").any? { |c| c.name == "migrations_ran" }
    end

    def self.my_region_number
      # Use ApplicationRecord here because we need to query region information
      @my_region_number ||= ApplicationRecord.my_region_number
    end

    def self.my_region_created?
      ActiveRecord::Base.connection.exec_query(<<~SQL).first["exists"]
        SELECT EXISTS(
          SELECT id FROM miq_regions WHERE region = #{ActiveRecord::Base.connection.quote(my_region_number)}
        )
      SQL
    end

    def self.update_local_migrations_ran(version, direction)
      return unless migrations_column_present?
      return unless my_region_created?

      new_migrations = ActiveRecord::SchemaMigration.normalized_versions
      new_migrations << version if direction == :up
      migrations_value = ActiveRecord::Base.connection.quote(PG::TextEncoder::Array.new.encode(new_migrations))

      ActiveRecord::Base.connection.exec_query(<<~SQL)
        UPDATE miq_regions
        SET migrations_ran = #{migrations_value}
        WHERE region = #{ActiveRecord::Base.connection.quote(my_region_number)}
      SQL
    end
  end

  class RemoteRegionMigrationWatcher
    class HelperARClass < ActiveRecord::Base; end

    attr_reader :region, :subscription, :version

    def initialize(subscription, version)
      region_class  = Class.new(ActiveRecord::Base) { self.table_name = "miq_regions" }
      @region       = region_class.find_by(:region => subscription.provider_region)
      @subscription = subscription
      @version      = version
    end

    def wait_for_remote_region_migration(wait_time = 1)
      return unless wait_for_migration?

      Vmdb.rails_logger.info(wait_message)
      print(wait_message)

      while wait_for_migration?
        print(".")
        restart_subscription
        sleep(wait_time)
        region.reload
      end

      puts("\n")
    end

    private

    def wait_for_migration?
      migrations_column_present? ? !region.migrations_ran&.include?(version) : false
    end

    def migrations_column_present?
      @migrations_column_present ||= PglogicalMigrationHelper.migrations_column_present?
    end

    def wait_message
      @wait_message ||= "Waiting for remote region #{region.region} to run migration #{version}"
    end

    def restart_subscription
      c = HelperARClass.establish_connection.connection
      c.pglogical.subscription_disable(subscription.id)
      c.pglogical.subscription_enable(subscription.id)
    ensure
      HelperARClass.remove_connection
    end
  end

  def migrate(direction)
    PglogicalSubscription.all.each do |s|
      RemoteRegionMigrationWatcher.new(s, version.to_s).wait_for_remote_region_migration
    end

    ret = super
    PglogicalMigrationHelper.update_local_migrations_ran(version.to_s, direction)
    ret
  end
end

ActiveRecord::Migration.prepend(ArPglogicalMigration)
