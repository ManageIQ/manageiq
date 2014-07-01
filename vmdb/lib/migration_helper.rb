# MigrationHelper is a module that can be included into migrations to add
# additional helper methods, thus eliminating some duplication and database
# specific coding.
#
# If mixed into a non-migration class, the module expects the following methods
# to be defined as in a migration: connection, say, say_with_time.  Additionally,
# any "extension" methods will need the original method defined.  For example,
# remove_index_ex expects remove_index to be defined.
module MigrationHelper
  BULK_COPY_DIRECTORY = File.expand_path(File.join(Rails.root, %w{tmp bulk_copy}))

  #
  # Methods for index conversions
  #

  def remove_index_ex(table, columns, opts = nil)
    if opts && opts.has_key?(:name)
      remove_index table, :name => opts[:name]
    else
      remove_index table, columns
    end
  end

  #
  # Methods for id  and *_id column data type changes
  #

  def change_id_column(table, column, type)
    drop_pk(table) if column == :id
    change_column table, column, type
    add_pk(table) if column == :id
  end

  def change_id_columns(table, id_cols, type)
    id_cols.each { |c| change_id_column(table, c, type) }
  end

  def change_id_columns_for_large_tables(table, id_cols, type)
    if sqlserver? && !table_empty?(table)
      change_id_columns_via_table_copy_for_sqlserver table, id_cols, type
    else
      change_id_columns table, id_cols, type
    end
  end

  def change_id_columns_via_table_copy_for_sqlserver(table, id_cols, type)
    orig = "#{table}_orig".to_sym
    rename_table table, orig
    copy_schema_only orig, table
    id_cols.each do |c|
      change_column table, c, type
    end
    add_pk table
    copy_data orig, table
    drop_table orig
  end

  #
  # Helper methods
  #

  def sqlserver?
    connection.adapter_name == "SQLServer"
  end

  def postgresql?
    connection.adapter_name == "PostgreSQL"
  end

  def add_pk(*args)
    meth = "add_pk_#{connection.adapter_name.downcase}"
    self.send(meth, *args) if self.respond_to?(meth)
  end

  def drop_pk(*args)
    meth = "drop_pk_#{connection.adapter_name.downcase}"
    self.send(meth, *args) if self.respond_to?(meth)
  end

  def add_trigger(*args)
    meth = "add_trigger_#{connection.adapter_name.downcase}"
    self.send(meth, *args)
  end

  def drop_trigger(*args)
    meth = "drop_trigger_#{connection.adapter_name.downcase}"
    self.send(meth, *args)
  end

  def add_table_inheritance(*args)
    meth = "add_table_inheritance_#{connection.adapter_name.downcase}"
    self.send(meth, *args)
  end

  def drop_table_inheritance(*args)
    meth = "drop_table_inheritance_#{connection.adapter_name.downcase}"
    self.send(meth, *args)
  end

  def bulk_copy_export(*args)
    meth = "bulk_copy_export_#{connection.adapter_name.downcase}"
    self.send(meth, *args)
  end

  def bulk_copy_import(*args)
    meth = "bulk_copy_import_#{connection.adapter_name.downcase}"
    self.send(meth, *args)
  end

  def bulk_copy_transfer(*args)
    meth = "bulk_copy_transfer_#{connection.adapter_name.downcase}"
    self.send(meth, *args)
  end

  def bulk_copy_filename(table, options = {})
    File.join(BULK_COPY_DIRECTORY, options[:filename] || "#{table}.sql")
  end

  def bulk_copy_delete(table, options = {})
    File.delete(bulk_copy_filename(table, options)) rescue nil
  end

  def with_identity_insert(table)
    raise "no block given" unless block_given?
    meth = "with_identity_insert_#{connection.adapter_name.downcase}"
    if self.respond_to?(meth)
      self.send(meth, table) { yield }
    else
      yield
    end
  end

  def table_empty?(table)
    sql = Arel::Table.new(table).project("*").take(1).to_sql
    connection.select_all(sql).length == 0
  end

  def sanitize_sql_for_conditions(conditions, table)
    Object.const_set(:DummyActiveRecordForMigrationHelper, Class.new(ActiveRecord::Base)) unless defined?(::DummyActiveRecordForMigrationHelper)
    DummyActiveRecordForMigrationHelper.send(:sanitize_sql_for_conditions, conditions, table)
  end

  def say_batch_started(count)
    say "Processing #{count} rows", :subitem
    @batch_total = count.to_f
    @batch_count = 0
  end

  def say_batch_processed(count)
    Thread.exclusive do
      @batch_count += count
      say "#{count} rows (#{"%.2f" % (@batch_count / @batch_total * 100)}% - #{@batch_count} total)", :subitem if count > 0
      @batch_count
    end
  end

  #
  # Table copy methods
  #

  # Copies the schema of the table, but not the primary key, seed values, nor indexes.
  def copy_schema_only(from_table, to_table)
    say_with_time("copy_schema_only(:#{from_table}, :#{to_table})") do
      from_table = connection.quote_table_name(from_table)
      to_table   = connection.quote_table_name(to_table)
      connection.execute("SELECT * INTO #{to_table} FROM #{from_table} WHERE 1 = 2")
    end
  end

  def copy_data(from_table, to_table, options = {})
    say_with_time("copy_data(:#{from_table}, :#{to_table})") do
      via = options[:via] || "insert_select_batches"
      self.send("copy_data_via_#{via}", from_table, to_table, options)
    end
  end

  def copy_data_via_insert_select_direct(from_table, to_table, options = {})
    columns      = connection.columns(to_table).collect { |col| connection.quote_column_name(col.name) }.join(",")
    from_table   = connection.quote_table_name(from_table)
    to_table     = connection.quote_table_name(to_table)
    conditions   = sanitize_sql_for_conditions(options[:conditions], from_table) if options[:conditions]
    where_clause = "WHERE #{conditions}" if conditions

    rows = connection.select_value("SELECT COUNT(id) FROM #{from_table} #{where_clause}").to_i
    say_batch_started(rows)
    return if rows == 0

    select_sql = "SELECT #{columns} FROM #{from_table} #{where_clause}"
    copy_data_via_insert_select(to_table, columns, select_sql)
  end

  def copy_data_via_insert_select_batches(from_table, to_table, options = {})
    batch_size   = options[:batch_size] || 100_000
    columns      = connection.columns(to_table).collect { |col| connection.quote_column_name(col.name) }.join(",")
    from_table   = connection.quote_table_name(from_table)
    to_table     = connection.quote_table_name(to_table)
    conditions   = sanitize_sql_for_conditions(options[:conditions], from_table) if options[:conditions]
    where_clause = "WHERE #{conditions}" if conditions

    last_id = connection.select_value("SELECT MAX(id) FROM #{to_table}").to_i

    rows = connection.select_value("SELECT COUNT(id) FROM #{from_table} #{where_clause} #{conditions ? "AND " : "WHERE "} id > #{last_id}").to_i
    say_batch_started(rows)
    return if rows == 0

    max_id = connection.select_value("SELECT MAX(id) FROM #{from_table} #{where_clause}").to_i

    select_sql_common = Arel::Table.new(from_table).project(columns).order(:id).take(batch_size)
    select_sql_common = select_sql_common.where(Arel.sql(conditions)) if conditions
    while last_id != max_id
      select_sql = select_sql_common.where(Arel.sql("id > #{last_id}"))
      copy_data_via_insert_select(to_table, columns, select_sql.to_sql)
      last_id = connection.select_value("SELECT MAX(id) FROM #{to_table}").to_i
    end
  end

  def copy_data_via_insert_select(to_table, columns, select_sql)
    with_identity_insert(to_table) do
      result = connection.execute("INSERT INTO #{to_table} (#{columns}) #{select_sql}")
      count  = result.respond_to?(:cmd_tuples) ? result.cmd_tuples : (result.respond_to?(:count) ? result.count : result.to_i)
      say_batch_processed(count)
    end
  end

  def copy_data_via_bulk_copy(from_table, to_table, options = {})
    return unless table_empty?(to_table)
    bulk_copy_transfer from_table, to_table, options
  end

  #
  # Column data migration methods
  #

  def change_data(table, column, from_value, to_value, options = {})
    say_with_time("Change #{table}.#{column} from '#{from_value}' to '#{to_value}'") do
      via = options[:via] || "batches"
      self.send("change_data_#{via}", table, column, from_value, to_value, options)
    end
  end

  def change_data_direct(table, column, from_value, to_value, options = {})
    from_value = sanitize_sql_for_conditions({column => from_value}, table)
    to_value   = "#{connection.quote_column_name(column)} = #{connection.quote(to_value)}"
    table      = connection.quote_table_name(table)

    rows = connection.select_value("SELECT COUNT(id) FROM #{table} WHERE #{from_value}").to_i
    say_batch_started(rows)
    return if rows == 0

    connection.update("UPDATE #{table} SET #{to_value} WHERE #{from_value}")
  end

  def change_data_batches(table, column, from_value, to_value, options = {})
    batch_size = options[:batch_size] || 100_000
    from_value = sanitize_sql_for_conditions({column => from_value}, table)
    to_value   = "#{connection.quote_column_name(column)} = #{connection.quote(to_value)}"
    table      = connection.quote_table_name(table)

    rows = connection.select_value("SELECT COUNT(id) FROM #{table} WHERE #{from_value}").to_i
    say_batch_started(rows)
    return if rows == 0

    select_sql = Arel::Table.new(table).project(:id).where(Arel.sql(from_value)).take(batch_size).to_sql
    loop do
      ids = connection.select_all(select_sql).collect { |r| r["id"] }
      break if ids.length == 0
      ids_clause = sanitize_sql_for_conditions({:id => ids}, table)
      count = connection.update("UPDATE #{table} SET #{to_value} WHERE #{ids_clause}")
      say_batch_processed(count)
      break if count < batch_size
    end
  end

  #
  # Adapter specific methods
  #

  def with_identity_insert_sqlserver(table)
    connection.transaction do
      connection.execute("SET IDENTITY_INSERT #{table} ON")
      begin
        yield
      ensure
        connection.execute("SET IDENTITY_INSERT #{table} OFF") rescue nil
      end
    end
  end

  def add_pk_sqlserver(table)
    say_with_time("add_pk(:#{table})") do
      connection.execute("ALTER TABLE #{connection.quote_table_name(table)} ADD PRIMARY KEY (id)").to_s
    end
  end

  def drop_pk_sqlserver(table)
    say_with_time("drop_pk(:#{table})") do
      connection.send(:remove_pk_constraint, table)
    end
  end

  def add_trigger_postgresql(direction, table, name, body)
    say_with_time("add_trigger(:#{direction}, :#{table}, :#{name})") do
      add_trigger_function_postgresql(name, body)
      add_trigger_hook_postgresql(direction, name, table, name)
    end
  end

  def add_trigger_function_postgresql(name, body)
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

  def add_trigger_hook_postgresql(direction, name, table, function)
    connection.execute <<-EOSQL, 'Create trigger'
      CREATE TRIGGER #{name}
      #{direction.to_s.upcase} INSERT ON #{table}
      FOR EACH ROW EXECUTE PROCEDURE #{function}();
    EOSQL
  end

  def drop_trigger_postgresql(table, name)
    say_with_time("drop_trigger(:#{table}, :#{name})") do
      connection.execute("DROP TRIGGER IF EXISTS #{name} ON #{table};", 'Drop trigger')
      connection.execute("DROP FUNCTION IF EXISTS #{name}();", 'Drop trigger function')
    end
  end

  def add_table_inheritance_postgresql(table, inherit_from, options = {})
    say_with_time("add_table_inheritance(:#{table}, :#{inherit_from})") do
      conditions = sanitize_sql_for_conditions(options[:conditions], table)
      connection.execute("ALTER TABLE #{table} ADD CONSTRAINT #{table}_inheritance_check CHECK (#{conditions})", 'Add inheritance check constraint')
      connection.execute("ALTER TABLE #{table} INHERIT #{inherit_from}", 'Add table inheritance')
    end
  end

  def drop_table_inheritance_postgresql(table, inherit_from)
    say_with_time("drop_table_inheritance(:#{table}, :#{inherit_from})") do
      connection.execute("ALTER TABLE #{table} DROP CONSTRAINT #{table}_inheritance_check", 'Drop inheritance check constraint')
      connection.execute("ALTER TABLE #{table} NO INHERIT #{inherit_from}", 'Drop table inheritance')
    end
  end

  def bulk_copy_export_postgresql(table, options = {})
    bulk_copy_postgresql(:export, table, options)
  end

  def bulk_copy_import_postgresql(table, options = {})
    bulk_copy_postgresql(:import, table, options)
  end

  # TODO: possible overlap with MiqPostgresAdmin
  def bulk_copy_postgresql(direction, table, options = {})
    raise ArgumentError, "direction must be either :export or :import" unless [:export, :import].include?(direction)

    options = options.reverse_merge(Rails.configuration.database_configuration[Rails.env].symbolize_keys)

    file = bulk_copy_filename(table, options)

    case Platform::OS
    when :win32
      pre     = "set PGPASSWORD=#{options[:password]}&&" if options[:password]
      copy    = "\\COPY"
      to_from = "'#{file}'"
      post    = "&& set PGPASSWORD="
    else
      case direction
      when :export
        pre     = "PGPASSWORD=#{options[:password]}" if options[:password]
        to_from = "STDOUT"
        post    = "| gzip -c - > #{file}"
      when :import
        pre     = "gunzip -c #{file} |"
        pre    += " PGPASSWORD=#{options[:password]}" if options[:password]
        to_from = "STDIN"
        post    = ""
      end

      copy = "\\\\COPY"
    end

    conditions =
      if direction == :export && options[:conditions]
        "(SELECT * FROM #{table} WHERE #{sanitize_sql_for_conditions(options[:conditions], table)})"
      else
        table
      end
    psql_host = ""
    psql_host << "-h #{options[:host]} " if options[:host]
    psql_host << "-p #{options[:port]} " if options[:port]
    psql_cmd = "#{copy} #{conditions} #{direction == :export ? "TO" : "FROM"} #{to_from} WITH BINARY"
    psql = "psql #{psql_host} -U #{options[:username]} -w -d #{options[:database]} -c \"#{psql_cmd}\""
    cmd = "#{pre} #{psql} #{post}"

    require 'fileutils'
    FileUtils.mkdir_p(BULK_COPY_DIRECTORY)
    `#{cmd}`
    status = $?.to_i
    raise "postgresql command failed with status #{status}: #{cmd}" unless status == 0
  end

  def bulk_copy_transfer_postgresql(from_table, to_table, options = {})
    options = options.reverse_merge(Rails.configuration.database_configuration[Rails.env].symbolize_keys)

    case Platform::OS
    when :win32
      pre  = "set PGPASSWORD=#{options[:password]}&&" if options[:password]
      pre2  = ""
      copy = "\\COPY"
      post = "&& set PGPASSWORD="
    else
      pre  = "PGPASSWORD=#{options[:password]}" if options[:password]
      pre2  = "PGPASSWORD=#{options[:password]}" if options[:password]
      copy = "\\\\COPY"
      post = ""
    end

    from_conditions =
      if options[:conditions]
        "(SELECT * FROM #{from_table} WHERE #{sanitize_sql_for_conditions(options[:conditions], from_table)})"
      else
        from_table
      end

    psql_export_cmd = "#{copy} #{from_conditions} TO STDOUT WITH BINARY"
    psql_import_cmd = "#{copy} #{to_table} FROM STDIN WITH BINARY"
    psql_host = ""
    psql_host << "-h #{options[:host]} " if options[:host]
    psql_host << "-p #{options[:port]} " if options[:port]

    psql_export = "psql #{psql_host} -U #{options[:username]} -w -d #{options[:database]} -c \"#{psql_export_cmd}\""
    psql_import = "psql #{psql_host} -U #{options[:username]} -w -d #{options[:database]} -c \"#{psql_import_cmd}\""
    cmd = "#{pre} #{psql_export} | #{pre2} #{psql_import} #{post}"

    `#{cmd}`
    status = $?.to_i
    raise "postgresql command failed with status #{status}: #{cmd}" unless status == 0
  end
end

Dir.glob(File.join(File.dirname(__FILE__), "migration_helper", "*.rb")).each { |f| require f }
