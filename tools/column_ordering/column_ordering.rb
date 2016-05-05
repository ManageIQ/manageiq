require 'awesome_spawn'
require 'strscan'

class ColumnOrdering
  class ColumnOrderingError < StandardError; end

  attr_accessor :table

  SCHEMA_FILE = Rails.root.join("db/schema.yml").freeze

  def initialize(table, connection)
    @table = table
    @connection = connection
    raise ColumnOrderingError, "The database does not contain table #{table}" unless connection.tables.include?(table)
  end

  def expected_columns
    @expected_columns ||= YAML.load_file(SCHEMA_FILE)[table]
  end

  def current_columns
    @connection.columns(table).map(&:name)
  end

  def ordering_okay?
    expected_columns == current_columns
  end

  def fix_column_ordering
    assert_column_list_sizes_match! && assert_column_list_contents_match!

    if ordering_okay?
      puts "The columns of #{table} are correctly ordered"
      return
    end

    create_table_statement, remaining_schema_structure = parse_create_table

    begin
      @connection.begin_db_transaction

      puts "Retrieving old sequence value ..."
      pk, sequence = @connection.pk_and_sequence_for(table)
      raise ColumnOrderingError, "Failed to retrieve primary key and sequence for #{table}" unless pk && sequence
      sequence_value = @connection.select_value("SELECT nextval('#{sequence}')")
      puts "Retrieved old sequence value #{sequence_value}"

      puts "Renaming old table ..."
      @connection.rename_table(table, "#{table}_old")
      puts "Table renamed"

      puts "Creating new table ..."
      create_new_table = reordered_create_table_statement(create_table_statement)
      @connection.exec_query(create_new_table)
      puts "New table created as:\n#{create_new_table}"

      puts "Moving data into new table ..."
      @connection.exec_query(<<-SQL)
        INSERT INTO #{table} SELECT #{expected_columns.join(",")} FROM #{table}_old
      SQL
      puts "Data moved"

      puts "Dropping old table ..."
      @connection.exec_query("DROP TABLE #{table}_old")
      puts "Old table removed"

      puts "Recreating remaining schema structure ..."
      @connection.execute(remaining_schema_structure).check
      puts "Schema structure recreated"

      puts "Setting new sequence to old value ..."
      @connection.set_pk_sequence!(table, sequence_value)
      puts "Sequence value set"
    rescue
      @connection.exec_rollback_db_transaction
      raise
    end

    @connection.commit_db_transaction
    puts "Columns of table #{table} successfully reordered"
  end

  def table_dump
    connection_params = @connection.raw_connection.conninfo_hash
    conf = {
      :dbname   => connection_params[:dbname],
      :host     => connection_params[:host],
      :user     => connection_params[:user],
      :password => connection_params[:password],
      :port     => connection_params[:port]
    }.delete_blanks

    params = {
      :s => nil,
      :t => table,
      :d => PG::Connection.parse_connect_args(conf)
    }

    pg_dump_result = AwesomeSpawn.run("pg_dump", :params => params)

    raise ColumnOrderingError <<-ERROR.gsub!(/^ +/, "") if pg_dump_result.failure?
      '#{pg_dump_result.command_line}' failed with #{pg_dump_result.exit_status}:

      stdout: #{pg_dump_result.output}
      stderr: #{pg_dump_result.error}
    ERROR

    pg_dump_result.output
  end

  # Separates the create table statement from the rest of the table dump
  # @returns create_table_statement, remaining_structure_dump
  def parse_create_table
    create_table = ""
    rest = table_dump.gsub(/create table #{table} \(.*?\);/mi) do |match|
      create_table = match
      ""
    end

    return create_table, rest
  end

  # Takes a valid create table SQL statement and partitions it into three parts:
  #  - The start of the statement ("CREATE TABLE table (")
  #  - The parameter list ("id bigint primary key, data varchar(255), CONSTRAINT ...")
  #  - The end of the statement (") INHERITS (other_table);")
  def self.partition_create_table(create_table_statement)
    scanner = StringScanner.new(create_table_statement)

    create_table_statement_start = scanner.scan_until(/\(/)
    paren_stack = 1
    create_table_statement_end = ""

    params = ""
    until scanner.eos?
      tok = scanner.scan_until(/\(|\)/)

      case tok[-1]
      when "("
        paren_stack += 1
      when ")"
        paren_stack -= 1
        if paren_stack == 0
          create_table_statement_end = tok[-1] + scanner.rest
          scanner.terminate

          tok = tok[0..-2]
        end
      end

      params << tok
    end

    return create_table_statement_start, params, create_table_statement_end
  end

  # Takes a parameter string and returns a column name to parameter string hash for
  # the columns and an array of constraint strings
  def self.parameters_to_objects(params)
    paren_stack = 0
    column_hash = {}
    constraints = []
    current_param = ""
    scanner = StringScanner.new(params)

    until scanner.eos?
      tok = scanner.scan_until(/\(|\)|,/)

      if tok
        current_param << tok
      else
        current_param << scanner.rest
        scanner.terminate
      end

      if paren_stack == 0 && (tok.nil? || tok.end_with?(","))
        current_param.strip!
        val = current_param.end_with?(",") ? current_param[0..-2] : current_param
        key = val.split.first
        if /^constraint$|^check$/i =~ key
          constraints << val
        else
          key = key[1..-2] if key.start_with?('"') && key.end_with?('"')
          column_hash[key] = val
        end
        current_param = ""
      elsif tok.end_with?("(")
        paren_stack += 1
      elsif tok.end_with?(")")
        paren_stack -= 1
      end
    end

    return column_hash, constraints
  end

  def new_parameter_string(column_hash, constraint_strings)
    (expected_columns.map { |col| column_hash[col] }.delete_blanks + constraint_strings).join(",\n")
  end

  def reordered_create_table_statement(current_create_table)
    create_table_start, parameter_list, create_table_end = self.class.partition_create_table(current_create_table)

    column_hash, constraint_strings = self.class.parameters_to_objects(parameter_list)
    new_parameter_list = new_parameter_string(column_hash, constraint_strings)

    "#{create_table_start}#{new_parameter_list}#{create_table_end}"
  end

  private

  def assert_column_list_sizes_match!
    return if current_columns.length == expected_columns.length
    raise ColumnOrderingError <<-ERROR.gsub!(/^ +/, "")
      Current and expected column arrays are of different size for table #{table}

      expected: #{expected_columns.inspect}
      got:      #{current_columns.inspect}
    ERROR
  end

  def assert_column_list_contents_match!
    return if current_columns.sort == expected_columns.sort
    raise ColumnOrderingError <<-ERROR.gsub!(/^ +/, "")
      Current and expected column arrays have different contents for #{table}

      expected: #{expected_columns.inspect}
      got:      #{current_columns.inspect}
    ERROR
  end
end
