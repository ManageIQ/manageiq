describe FailoverDatabases do
  before do
    connection = ActiveRecord::Base.connection
    connection.execute("CREATE SCHEMA repmgr_miq")

    connection.execute(<<-SQL)
      CREATE TABLE repmgr_miq.repl_nodes (
      type text NOT NULL,
      conninfo text NOT NULL,
      active boolean DEFAULT true NOT NULL)
    SQL

    connection.execute(<<-SQL)
      INSERT INTO
        repmgr_miq.repl_nodes(type, conninfo, active)
      VALUES
        ('master', 'host=1.1.1.1 user=root dbname=vmdb_test', 'true'),
        ('standby', 'host=2.2.2.2 user=root dbname=vmdb_test', 'true'),
        ('standby', 'host=3.3.3.3 user=root dbname=vmdb_test', 'false')
    SQL
  end

  after do
    remove_file
  end

  describe ".all_databases" do
    it "returns list of all available databases saved in yaml file" do
      list = described_class.all_databases

      expect(list.size).to be 3
      expect(list).to include({:type => "master", :host => "1.1.1.1", :dbname => "vmdb_test",
                               :user => "root", :active => true},
                              {:type => "standby", :host => "2.2.2.2", :dbname => "vmdb_test",
                               :user => "root", :active => true},
                              {:type => "standby", :host => "3.3.3.3", :dbname => "vmdb_test",
                               :user => "root", :active => false})
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
      expect(list).to include({:type => "master", :host => "1.1.1.1", :dbname => "vmdb_test",
                              :user => "root", :active => true},
                              {:type => "standby", :host => "2.2.2.2", :dbname => "vmdb_test",
                               :user => "root", :active => true},
                              {:type => "standby", :host => "3.3.3.3", :dbname => "vmdb_test",
                               :user => "root", :active => false})
    end
  end

  describe ".refresh_databases_list" do
    it "override existing yaml file and returns updated list of databases" do
      list = described_class.all_databases
      expect(list.size).to be 3

      add_new_record

      list = described_class.refresh_databases_list
      expect(list.size).to be 4
      expect(list).to include(:type => "standby", :host => "4.4.4.4", :dbname => "some_db",
                              :user => "root", :active => true)
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

  def add_new_record
    connection = ApplicationRecord.connection
    connection.execute(<<-SQL)
      INSERT INTO
        repmgr_miq.repl_nodes(type, conninfo, active)
      VALUES
        ('standby', 'host=4.4.4.4 user=root dbname=some_db', 'true')
    SQL
  end

  def remove_file
    if File.exist?(described_class::FAILOVER_DATABASES_YAML_FILE)
      File.delete(described_class::FAILOVER_DATABASES_YAML_FILE)
    end
  end
end
