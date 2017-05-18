$LOAD_PATH << Rails.root.join("tools")

require "column_ordering/column_ordering"

describe ColumnOrdering do
  let(:connection) { ApplicationRecord.connection }
  let(:data_dir)   { File.join(File.expand_path(__dir__), "data") }
  let(:table)      { "metrics_04" }

  def data_file_contents(file)
    File.read(File.join(data_dir, file))
  end

  def column_hash_for(table)
    YAML.load(data_file_contents("#{table}_cols.yml"))
  end

  def constraints_for(table)
    YAML.load(data_file_contents("#{table}_constraints.yml"))
  end

  before(:all) do
    @orig_stdout = $stdout
    @orig_stderr = $stderr
    $stdout = File.open(File::NULL, "w")
    $stderr = File.open(File::NULL, "w")
  end

  after(:all) do
    $stdout = @orig_stdout
    $stderr = @orig_stderr
  end

  describe "#fix_column_ordering" do
    before do
      connection.execute(data_file_contents("test.sql"))
      connection.exec_query("INSERT INTO TEST (data, uuid) VALUES ('stuff', 'unique')")
      connection.exec_query("INSERT INTO TEST (data, uuid) VALUES ('more stuff', 'unique1')")
    end

    it "reorders the columns on a table" do
      co = described_class.new("test", connection)
      allow(co).to receive(:table_dump).and_return(data_file_contents("test.sql"))
      allow(co).to receive(:expected_columns).and_return(%w(id uuid data))

      expect(connection).to receive(:begin_db_transaction)
      expect(connection).to receive(:commit_db_transaction)
      expect(co.current_columns).to eq(%w(id data uuid))
      expect(co.ordering_okay?).to be false

      co.fix_column_ordering

      expect(co.ordering_okay?).to be true
      data = connection.select_rows("SELECT * FROM test")
      expect(data).to eq([[1, "unique", "stuff"], [2, "unique1", "more stuff"]])
    end
  end

  describe "#parse_create_table" do
    it "parses the correct strings" do
      allow(connection).to receive(:tables).and_return([table])
      co = described_class.new(table, connection)

      expect(co).to receive(:table_dump).and_return(data_file_contents("#{table}.sql"))
      create_table, rest = co.parse_create_table

      expect(create_table).to eq(data_file_contents("#{table}_create.sql").strip)
      expect(rest).to eq(data_file_contents("#{table}_rest.sql"))
    end
  end

  describe "#ordering_okay?" do
    it "returns false when the ordering is not okay" do
      stub_const("ColumnOrdering::SCHEMA_FILE", File.join(data_dir, "#{table}.yml"))
      allow(connection).to receive(:tables).and_return([table])
      co = described_class.new(table, connection)

      allow(co).to receive(:current_columns).and_return(column_hash_for(table).keys)
      expect(co.ordering_okay?).to be false
    end
  end

  describe "#new_parameter_string" do
    it "properly reorders the columns" do
      stub_const("ColumnOrdering::SCHEMA_FILE", File.join(data_dir, "#{table}.yml"))
      allow(connection).to receive(:tables).and_return([table])
      co = described_class.new(table, connection)

      new_string = co.new_parameter_string(column_hash_for(table), constraints_for(table))
      expect(new_string).to eq(data_file_contents("#{table}_new_params").strip)
    end
  end

  describe ".partition_create_table" do
    it "parses the correct strings" do
      start, params, finish = described_class.partition_create_table(data_file_contents("#{table}_create.sql"))

      expect(start).to eq("CREATE TABLE metrics_04 (")
      expect(params).to eq(data_file_contents("#{table}_params"))
      expect(finish).to eq(")\nINHERITS (metrics);\n")
    end
  end

  describe ".parameters_to_objects" do
    it "parses the parameters into objects" do
      col_hash, constraints = described_class.parameters_to_objects(data_file_contents("#{table}_params"))

      expect(col_hash).to eq(column_hash_for(table))
      expect(constraints).to eq(constraints_for(table))
    end
  end
end
