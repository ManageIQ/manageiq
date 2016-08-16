require 'postgres_ha_admin/failover_databases'
require 'pg'

describe PostgresHaAdmin::FailoverDatabases do
  let(:logger) { Logger.new(@logger_file) }
  let(:failover_databases) { described_class.new(@yml_file.path, logger) }

  before do
    @yml_file = Tempfile.new('failover_databases.yml')
    @logger_file = Tempfile.new('ha_admin.log')
  end

  after do
    @yml_file.close(true)
    @logger_file.close(true)
  end

  describe "#active_databases" do
    it "return list of active databases saved in 'config/failover_databases.yml'" do
      File.write(@yml_file, initial_db_list.to_yaml)
      expect(failover_databases.active_databases).to contain_exactly(
        {:type => 'master', :active => true, :host => '203.0.113.1', :user => 'root', :dbname => 'vmdb_test'},
        {:type => 'standby', :active => true, :host => '203.0.113.2', :user => 'root', :dbname => 'vmdb_test'})
    end
  end

  context "accessing database" do
    after do
      @connection.exec("ROLLBACK")
      @connection.finish
    end

    before do
      # @connection = PG::Connection.open(:dbname => 'vmdb_test')
      begin
        @connection = PG::Connection.open(:dbname => 'travis', :user => 'travis')
      rescue PG::ConnectionBad
        skip "travis database does not exist"
      end

      @connection.exec("START TRANSACTION")
      @connection.exec(<<-SQL)
        CREATE TABLE #{described_class::TABLE_NAME}  (
          type text NOT NULL,
          conninfo text NOT NULL,
          active boolean DEFAULT true NOT NULL
        )
      SQL

      @connection.exec(<<-SQL)
        INSERT INTO
          #{described_class::TABLE_NAME}(type, conninfo, active)
        VALUES
          ('master', 'host=203.0.113.1 user=root dbname=vmdb_test', 'true'),
          ('standby', 'host=203.0.113.2 user=root dbname=vmdb_test', 'true'),
          ('standby', 'host=203.0.113.3 user=root dbname=vmdb_test', 'false')
      SQL
    end

    describe "#update_failover_yml" do
      it "updates 'failover_databases.yml'" do
        failover_databases.update_failover_yml(@connection)

        yml_hash = YAML.load_file(@yml_file)
        expect(yml_hash).to eq initial_db_list

        add_new_record

        failover_databases.update_failover_yml(@connection)
        yml_hash = YAML.load_file(@yml_file)
        expect(yml_hash).to eq new_db_list
      end
    end

    describe "#query_repmgr" do
      it "returns list of all databases registered in repmgr" do
        result = failover_databases.query_repmgr(@connection)
        expect(result).to eq initial_db_list
      end
    end
  end

  def initial_db_list
    arr = []
    arr << {:type => 'master', :active => true, :host => '203.0.113.1', :user => 'root', :dbname => 'vmdb_test'}
    arr << {:type => 'standby', :active => true, :host => '203.0.113.2', :user => 'root', :dbname => 'vmdb_test'}
    arr << {:type => 'standby', :active => false, :host => '203.0.113.3', :user => 'root', :dbname => 'vmdb_test'}
    arr
  end

  def new_db_list
    initial_db_list << {:type => 'standby', :active => true, :host => '203.0.113.4',
                        :user => 'root', :dbname => 'some_db'}
  end

  def add_new_record
    @connection.exec(<<-SQL)
      INSERT INTO
        #{described_class::TABLE_NAME}(type, conninfo, active)
      VALUES
        ('standby', 'host=203.0.113.4 user=root dbname=some_db', 'true')
    SQL
  end
end
