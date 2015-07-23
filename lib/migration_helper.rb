# MigrationHelper is a module that can be included into migrations to add
# additional helper methods, thus eliminating some duplication and database
# specific coding.
#
# If mixed into a non-migration class, the module expects the following methods
# to be defined as in a migration: connection, say, say_with_time.  Additionally,
# any "extension" methods will need the original method defined.  For example,
# remove_index_ex expects remove_index to be defined.
module MigrationHelper
  def sanitize_sql_for_conditions(conditions, table)
    Object.const_set(:DummyActiveRecordForMigrationHelper, Class.new(ActiveRecord::Base)) unless defined?(::DummyActiveRecordForMigrationHelper)
    DummyActiveRecordForMigrationHelper.send(:sanitize_sql_for_conditions, conditions, table)
  end

  #
  # Triggers
  #

  def add_trigger(direction, table, name, body)
    say_with_time("add_trigger(:#{direction}, :#{table}, :#{name})") do
      add_trigger_function(name, body)
      add_trigger_hook(direction, name, table, name)
    end
  end

  def add_trigger_function(name, body)
    connection.execute <<-EOSQL, 'Create trigger function'
      CREATE OR REPLACE FUNCTION #{name}()
      RETURNS TRIGGER AS $$
      BEGIN
        #{body}
      END;
      $$
      LANGUAGE plpgsql;
    EOSQL
  end

  def add_trigger_hook(direction, name, table, function)
    connection.execute <<-EOSQL, 'Create trigger'
      CREATE TRIGGER #{name}
      #{direction.to_s.upcase} INSERT ON #{table}
      FOR EACH ROW EXECUTE PROCEDURE #{function}();
    EOSQL
  end

  def drop_trigger(table, name)
    say_with_time("drop_trigger(:#{table}, :#{name})") do
      connection.execute("DROP TRIGGER IF EXISTS #{name} ON #{table};", 'Drop trigger')
      connection.execute("DROP FUNCTION IF EXISTS #{name}();", 'Drop trigger function')
    end
  end

  #
  # Table inheritance
  #

  def add_table_inheritance(table, inherit_from, options = {})
    say_with_time("add_table_inheritance(:#{table}, :#{inherit_from})") do
      conditions = sanitize_sql_for_conditions(options[:conditions], table)
      connection.execute("ALTER TABLE #{table} ADD CONSTRAINT #{table}_inheritance_check CHECK (#{conditions})", 'Add inheritance check constraint')
      connection.execute("ALTER TABLE #{table} INHERIT #{inherit_from}", 'Add table inheritance')
    end
  end

  def drop_table_inheritance(table, inherit_from)
    say_with_time("drop_table_inheritance(:#{table}, :#{inherit_from})") do
      connection.execute("ALTER TABLE #{table} DROP CONSTRAINT #{table}_inheritance_check", 'Drop inheritance check constraint')
      connection.execute("ALTER TABLE #{table} NO INHERIT #{inherit_from}", 'Drop table inheritance')
    end
  end
end

Dir.glob(File.join(File.dirname(__FILE__), "migration_helper", "*.rb")).each { |f| require f }
