require 'postgres_ha_admin/failover_databases'
require 'postgres_ha_admin/postgres_ha_admin'
require 'spec/support/test_env_helper'
require 'pg'

describe PostgresHaAdmin::FailoverDatabases do
  subject do
    described_class.new(TestEnvHelper::CONFIG_DIR, TestEnvHelper::CONFIG_DIR, :dbname => 'travis', :user => 'travis')
    # described_class.new(TestEnvHelper::CONFIG_DIR, TestEnvHelper::CONFIG_DIR, :dbname => 'vmdb_test')
  end

  # let(:connection) { PG::Connection.open(:dbname => 'vmdb_test') }
  let(:connection) do
    begin
      PG::Connection.open(:dbname => 'travis', :user => 'travis')
    rescue PG::ConnectionBad => _err
      skip "travis database does not exist"
    end
  end

  around(:each) do |example|
    begin
      connection.exec("START TRANSACTION")
      connection.exec("CREATE SCHEMA repmgr_miq")

      connection.exec(<<-SQL)
        CREATE TABLE repmgr_miq.repl_nodes (
          type text NOT NULL,
          conninfo text NOT NULL,
          active boolean DEFAULT true NOT NULL
        )
      SQL

      connection.exec(<<-SQL)
        INSERT INTO
          repmgr_miq.repl_nodes(type, conninfo, active)
        VALUES
          ('master', 'host=1.1.1.1 user=root dbname=vmdb_test', 'true'),
          ('standby', 'host=2.2.2.2 user=root dbname=vmdb_test', 'true'),
          ('standby', 'host=3.3.3.3 user=root dbname=vmdb_test', 'false')
      SQL

      example.run
    ensure
      connection.exec("ROLLBACK")
      connection.finish
      remove_file
    end
  end

  describe "#all_databases" do
    it "returns list of all available databases saved in yaml file" do
      list = subject.all_databases(connection)

      expect(list.size).to be 3
      expect(list).to include({:type => "master", :host => "1.1.1.1", :dbname => "vmdb_test",
                               :user => "root", :active => true},
                              {:type => "standby", :host => "2.2.2.2", :dbname => "vmdb_test",
                               :user => "root", :active => true},
                              {:type => "standby", :host => "3.3.3.3", :dbname => "vmdb_test",
                               :user => "root", :active => false})
    end

    it "create yaml file with list of available databases if file did not exist" do
      expect(File.exist?(subject.yml_file)).to be false

      subject.all_databases(connection)
      expect(File.exist?(subject.yml_file)).to be true
    end

    it "if yaml file exists, it loads list of databases from existing file" do
      list = subject.all_databases(connection)
      expect(list.size).to be 3

      add_new_record

      subject.all_databases(connection)
      expect(list.size).to be 3
      expect(list).to include({:type => "master", :host => "1.1.1.1", :dbname => "vmdb_test",
                              :user => "root", :active => true},
                              {:type => "standby", :host => "2.2.2.2", :dbname => "vmdb_test",
                               :user => "root", :active => true},
                              {:type => "standby", :host => "3.3.3.3", :dbname => "vmdb_test",
                               :user => "root", :active => false})
    end
  end

  describe "#refresh_databases_list" do
    it "override existing yaml file and returns updated list of databases" do
      list = subject.all_databases(connection)
      expect(list.size).to be 3

      add_new_record

      list = subject.refresh_databases_list(connection)
      expect(list.size).to be 4
      expect(list).to include(:type => "standby", :host => "4.4.4.4", :dbname => "some_db",
                              :user => "root", :active => true)
    end
  end

  describe "#standby_databases" do
    it "returns list of databases in standby mode" do
      list = subject.standby_databases(connection)
      expect(list.size).to eq 2
    end
  end

  describe "#active_standby_databases" do
    it "returns list of active databases in standby mode" do
      list = subject.active_standby_databases(connection)
      expect(list.size).to eq 1
    end
  end

  def add_new_record
    connection.exec(<<-SQL)
      INSERT INTO
        repmgr_miq.repl_nodes(type, conninfo, active)
      VALUES
        ('standby', 'host=4.4.4.4 user=root dbname=some_db', 'true')
    SQL
  end

  def remove_file
    if File.exist?(subject.yml_file)
      File.delete(subject.yml_file)
    end
    if File.exist?(subject.log_file)
      File.delete(subject.log_file)
    end
  end
end
