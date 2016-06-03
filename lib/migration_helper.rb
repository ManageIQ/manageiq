# MigrationHelper is a module that can be included into migrations to add
# additional helper methods, thus eliminating some duplication and database
# specific coding.
#
# If mixed into a non-migration class, the module expects the following methods
# to be defined as in a migration: connection, say, say_with_time.  Additionally,
# any "extension" methods will need the original method defined.  For example,
# remove_index_ex expects remove_index to be defined.
module MigrationHelper
  def sanitize_sql_for_conditions(conditions)
    Object.const_set(:DummyActiveRecordForMigrationHelper, Class.new(ActiveRecord::Base)) unless defined?(::DummyActiveRecordForMigrationHelper)
    DummyActiveRecordForMigrationHelper.send(:sanitize_sql_for_conditions, conditions)
  end

  #
  # Batching
  #

  def say_batch_started(count)
    say "Processing #{count} rows", :subitem
    @batch_total_started = Time.now.utc
    @batch_started = Time.now.utc
    @batch_total = count
    @batch_count = 0
  end

  def say_batch_processed(count)
    Thread.exclusive do
      if count > 0
        @batch_count += count

        progress = @batch_count / @batch_total.to_f * 100
        timing   = Time.now.utc - @batch_started
        estimate = estimate_batch_complete(@batch_total_started, progress)

        say "#{count} rows (#{"%.2f" % progress}% - #{@batch_count} total - #{"%.2f" % timing}s - ETA: #{estimate})", :subitem
      end

      @batch_started = Time.now.utc
      @batch_count
    end
  end

  def estimate_batch_complete(start_time, progress)
    klass = Class.new { extend ActionView::Helpers::DateHelper }
    estimated_end_time = start_time + (Time.now.utc - start_time) / (progress / 100.0)
    klass.distance_of_time_in_words(Time.now.utc, estimated_end_time, :include_seconds => true)
  end
  private :estimate_batch_complete

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
    quoted_name = connection.quote_table_name(name)
    quoted_body = connection.quote("BEGIN\n#{body}\nEND;\n")

    connection.execute <<-EOSQL, 'Create trigger function'
      CREATE OR REPLACE FUNCTION #{quoted_name}()
      RETURNS TRIGGER AS #{quoted_body}
      LANGUAGE plpgsql;
    EOSQL
  end

  def add_trigger_hook(direction, name, table, function)
    quoted_name = connection.quote_column_name(name)
    quoted_table = connection.quote_table_name(table)
    quoted_function = connection.quote_table_name(function)
    safe_direction = direction.downcase == 'before' ? 'BEFORE' : 'AFTER'

    connection.execute <<-EOSQL, 'Create trigger'
      CREATE TRIGGER #{quoted_name}
      #{safe_direction} INSERT ON #{quoted_table}
      FOR EACH ROW EXECUTE PROCEDURE #{quoted_function}();
    EOSQL
  end

  def drop_trigger(table, name)
    quoted_name = connection.quote_column_name(name)
    quoted_table = connection.quote_table_name(table)

    say_with_time("drop_trigger(:#{table}, :#{name})") do
      connection.execute("DROP TRIGGER IF EXISTS #{quoted_name} ON #{quoted_table};", 'Drop trigger')
      connection.execute("DROP FUNCTION IF EXISTS #{quoted_name}();", 'Drop trigger function')
    end
  end

  #
  # Table inheritance
  #

  def add_table_inheritance(table, inherit_from, options = {})
    quoted_table = connection.quote_table_name(table)
    quoted_inherit = connection.quote_table_name(inherit_from)
    quoted_constraint = connection.quote_column_name("#{table}_inheritance_check")

    say_with_time("add_table_inheritance(:#{table}, :#{inherit_from})") do
      conditions = sanitize_sql_for_conditions(options[:conditions])
      connection.execute("ALTER TABLE #{quoted_table} ADD CONSTRAINT #{quoted_constraint} CHECK (#{conditions})", 'Add inheritance check constraint')
      connection.execute("ALTER TABLE #{quoted_table} INHERIT #{quoted_inherit}", 'Add table inheritance')
    end
  end

  def drop_table_inheritance(table, inherit_from)
    quoted_table = connection.quote_table_name(table)
    quoted_inherit = connection.quote_table_name(inherit_from)
    quoted_constraint = connection.quote_column_name("#{table}_inheritance_check")

    say_with_time("drop_table_inheritance(:#{table}, :#{inherit_from})") do
      connection.execute("ALTER TABLE #{quoted_table} DROP CONSTRAINT #{quoted_constraint}", 'Drop inheritance check constraint')
      connection.execute("ALTER TABLE #{quoted_table} NO INHERIT #{quoted_inherit}", 'Drop table inheritance')
    end
  end

  def rename_class_references(mapping)
    reversible do |dir|
      dir.down { mapping = mapping.invert }

      condition_list = mapping.keys.map { |s| connection.quote(s) }.join(',')
      when_clauses = mapping.map { |before, after| "WHEN #{connection.quote before} THEN #{connection.quote after}" }.join(' ')

      type_columns_query = <<-SQL
        SELECT pg_class.oid::regclass::text, quote_ident(attname)
        FROM pg_class JOIN pg_attribute ON pg_class.oid = attrelid
        WHERE relkind = 'r'
          AND (attname = 'type' OR attname LIKE '%\\_type')
          AND atttypid IN ('text'::regtype, 'varchar'::regtype)
        ORDER BY relname, attname
      SQL

      select_rows(type_columns_query).each do |quoted_table, quoted_column|
        execute <<-SQL
          UPDATE #{quoted_table}
          SET #{quoted_column} = CASE #{quoted_column} #{when_clauses} END
          WHERE #{quoted_column} IN (#{condition_list})
        SQL
      end
    end
  end

  # Fixes issues where migrations were named incorrectly due to issues with the
  #   naming of 20150823120001_namespace_ems_openstack_availability_zones_null.rb
  def previously_migrated_as?(bad_date)
    connection.exec_delete(
      "DELETE FROM schema_migrations WHERE version = #{connection.quote(bad_date)}"
    ) > 0
  end
end
