describe FailoverDatabases do
  before(:each) do
    connection = ActiveRecord::Base.connection
    connection.execute("CREATE SCHEMA repmgr_miq")

    connection.execute(<<-SQL)
      CREATE TABLE repmgr_miq.repl_nodes (
      id integer NOT NULL,
      type text NOT NULL,
      active boolean DEFAULT true NOT NULL,
      CONSTRAINT repl_nodes_type_check CHECK ((type = ANY (ARRAY['master'::text, 'standby'::text, 'witness'::text]))))
    SQL

    connection.execute(<<-SQL)
      ALTER TABLE ONLY repmgr_miq.repl_nodes
      ADD CONSTRAINT repl_nodes_pkey PRIMARY KEY (id)
    SQL

    connection.execute(<<-SQL)
      INSERT INTO
        repmgr_miq.repl_nodes(id, type, active)
      VALUES
        (2, 'master', 'true'),
        (1, 'standby', 'true'),
        (3, 'standby', 'false')
    SQL
  end

  after(:each) do
    remove_file
  end

  describe ".all_databases" do
    it "returns list of all available databases saved in yaml file" do
      list = described_class.all_databases

      expect(list.size).to be 3
      expect(list).to match_array(initial_db_records)
    end

    it "create yaml file with list of available databases if file did not exist" do
      expect(File.exist?(described_class::FAILOVER_DATABASES_YAML_FILE)).to be false

      described_class.all_databases
      expect(File.exist?(described_class::FAILOVER_DATABASES_YAML_FILE)).to be true
    end

    it "if yaml file exists, it loads list of databases from existing file" do
      list = described_class.all_databases
      expect(list.size).to be 3

      add_new_record

      described_class.all_databases
      expect(list.size).to be 3
      expect(list).to match_array(initial_db_records)
    end
  end

  describe ".refresh_databases_list" do
    it "override existing yaml file and returns updated list of databases" do
      list = described_class.all_databases
      expect(list.size).to be 3

      add_new_record

      list = described_class.refresh_databases_list
      expect(list.size).to be 4
      expect(list).to include new_record
    end
  end

  describe ".standby_databases" do
    it "returns list of databases in standby mode" do
      list = described_class.standby_databases
      expect(list.size).to eq 2
    end
  end

  describe ".active_standby_databases" do
    it "returns list of active databases in standby mode" do
      list = described_class.active_standby_databases
      expect(list.size).to eq 1
    end
  end

  def initial_db_records
    [{"id"   => 1, "type" => "standby", "active" => true},
     {"id"   => 2, "type" => "master", "active" => true},
     {"id"   => 3, "type" => "standby", "active" => false}]
  end

  def new_record
    {"id" => 4, "type" => "standby", "active" => true}
  end

  def add_new_record
    connection = ApplicationRecord.connection
    connection.execute(<<-SQL)
      INSERT INTO
        repmgr_miq.repl_nodes(id, type, active)
      VALUES
        (4, 'standby', 'true')
    SQL
  end

  def remove_file
    if File.exist?(described_class::FAILOVER_DATABASES_YAML_FILE)
      File.delete(described_class::FAILOVER_DATABASES_YAML_FILE)
    end
  end
end
