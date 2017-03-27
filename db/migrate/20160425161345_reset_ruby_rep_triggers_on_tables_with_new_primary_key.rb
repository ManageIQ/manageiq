class ResetRubyRepTriggersOnTablesWithNewPrimaryKey < ActiveRecord::Migration[5.0]
  # This migration is intentionally left blank
  #
  # We removed the contents of the migration, but don't want to cause errors
  # when we check for the schema status on server startup.
  #
  # If someone has already migrated past this migration and the file is removed,
  # then they will see a message that looks like:
  #
  # MIQ(MiqServer.check_migrations_up_to_date) database schema is from a newer version of the product and may be incompatible.  Schema version is [20160922235000].  Missing files: [20160425161345]

  def up
    say "Migrating up NOOP migration for schema consistency"
  end
end
