module ArPglogicalMigration
  module ArPglogicalMigrationHelper
    def self.migrations_column_present?
      ActiveRecord::Base.connection.columns("miq_regions").any? { |c| c.name == "migrations_ran" }
    end

    def self.log_and_print(message)
      if @current_message == message
        print "."
      else
        Vmdb.rails_logger.info(message)
        print message
      end
      @current_message = message
    end

    class HelperARClass < ActiveRecord::Base; end

    def self.restart_subscription(s)
      c = HelperARClass.establish_connection.connection
      c.pglogical.subscription_disable(s.id)
      c.pglogical.subscription_enable(s.id)
    ensure
      HelperARClass.remove_connection
    end

    def self.wait_for_remote_region_migration(subscription, version, wait_time = 1)
      return unless migrations_column_present?
      region = MiqRegion.find_by(:region => subscription.provider_region)
      waited = false
      until region.migrations_ran&.include?(version)
        waited = true
        log_and_print("Waiting for remote region #{region.region} to run migration #{version}")
        restart_subscription(subscription)
        sleep(wait_time)
        region.reload
      end
      puts "\n" if waited
    end

    def self.update_local_migrations_ran(version, direction)
      return unless migrations_column_present?
      return unless (region = MiqRegion.my_region)

      new_migrations = ActiveRecord::SchemaMigration.normalized_versions
      new_migrations << version if direction == :up
      migrations_value = ActiveRecord::Base.connection.quote(PG::TextEncoder::Array.new.encode(new_migrations))

      ActiveRecord::Base.connection.exec_query(<<~SQL)
        UPDATE miq_regions
        SET migrations_ran = #{migrations_value}
        WHERE id = #{region.id}
      SQL
    end
  end

  def migrate(direction)
    PglogicalSubscription.all.each do |s|
      ArPglogicalMigrationHelper.wait_for_remote_region_migration(s, version.to_s)
    end

    ret = super
    ArPglogicalMigrationHelper.update_local_migrations_ran(version.to_s, direction)
    ret
  end
end

ActiveRecord::Migration.prepend(ArPglogicalMigration)
