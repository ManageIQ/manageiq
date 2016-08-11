require 'postgres_ha_admin/failover_monitor'

describe PostgresHaAdmin::FailoverMonitor do
  let(:db_yml) do
    yml = double('DatabaseYml')
    allow(yml).to receive(:pg_params_from_database_yml).and_return(:host => 'host.example.com', :user => 'root')
    yml
  end
  let(:failover_db) { double('FailoverDatabases') }
  let(:connection) do
    conn = double("PGConnection")
    allow(conn).to receive(:finish)
    conn
  end

  let(:failover_monitor) do
    expect(PostgresHaAdmin::DatabaseYml).to receive(:new).and_return(db_yml)
    expect(PostgresHaAdmin::FailoverDatabases).to receive(:new).and_return(failover_db)
    failover_instance = described_class.new('', '', @logger_file.path, 'test')
    logger = double('Logger')
    allow(logger).to receive(:info)
    allow(logger).to receive(:error)
    failover_instance.instance_variable_set("@logger", logger)
    failover_instance
  end

  before do
    @logger_file = Tempfile.new('ha_admin.log')
  end

  after do
    @logger_file.close(true)
  end

  describe "#monitor" do
    context "primary database is accessable" do
      before do
        allow(PG::Connection).to receive(:open).and_return(connection)
      end

      it "updates 'failover_databases.yml'" do
        expect(failover_db).to receive(:update_failover_yml).with(connection)
        failover_monitor.monitor
      end

      it "does not stop evm server and does not execute failover" do
        expect(failover_db).to receive(:update_failover_yml).with(connection)
        expect(failover_monitor).not_to receive(:stop_evmserverd)
        expect(failover_monitor).not_to receive(:execute_failover)
        expect(failover_monitor).not_to receive(:start_evmserver)
        failover_monitor.monitor
      end
    end

    context "primary database is not accessable" do
      let(:linux_admin) do
        linux_adm = double('LinuxAdmin')
        allow(LinuxAdmin::Service).to receive(:new).and_return(linux_adm)
        allow(linux_adm).to receive("running?").and_return(true)
        linux_adm
      end

      before do
        allow(PG::Connection).to receive(:open).and_return(nil, connection, connection)
      end

      describe "#host_for_primary_database" do
        it "return host if supplied connection established with primary database" do
          params = {:host => '203.0.113.2', :user => 'root', :dbname => 'vmdb_test'}
          expect(failover_db).to receive(:query_repmgr).with(connection).and_return(guery_repmanager_result)
          host = failover_monitor.host_for_primary_database(connection, params)
          expect(host).to eq '203.0.113.2'
        end

        it "return nil if supplied connection established with mot primary database" do
          params = {:host => '203.0.113.3', :user => 'root', :dbname => 'vmdb_test'}
          expect(failover_db).to receive(:query_repmgr).with(connection).and_return(guery_repmanager_result)
          host = failover_monitor.host_for_primary_database(connection, params)
          expect(host).to be nil
        end
      end

      it "stop evm server(if it is running) before failover attempt" do
        expect(linux_admin).to receive(:stop)
        expect(failover_monitor).to receive(:execute_failover).and_return(false)

        failover_monitor.monitor
      end

      it "updates 'database.yml' if there is available primary database and restart evm server" do
        allow(failover_monitor).to receive(:stop_evmserverd)
        allow(failover_monitor).to receive(:database_in_recovery?).with(connection).and_return(false)
        expect(failover_db).to receive(:active_databases).and_return(active_databases_list)
        expect(failover_db).to receive(:query_repmgr).exactly(2).times
          .with(connection).and_return(guery_repmanager_result)

        expect(failover_db).to receive(:update_failover_yml).with(connection)
        expect(db_yml).to receive(:update_database_yml)
        expect(linux_admin).to receive(:stop)
        expect(linux_admin).to receive(:start)

        failover_monitor.monitor
      end
    end
  end

  def active_databases_list
    arr = []
    arr << {:type => 'master', :active => true, :host => '203.0.113.1', :user => 'root', :dbname => 'vmdb_test'}
    arr << {:type => 'standby', :active => true, :host => '203.0.113.2', :user => 'root', :dbname => 'vmdb_test'}
    arr << {:type => 'standby', :active => true, :host => '203.0.113.3', :user => 'root', :dbname => 'vmdb_test'}
  end

  def guery_repmanager_result
    arr = []
    arr << {:type => 'standby', :active => false, :host => '203.0.113.1', :user => 'root', :dbname => 'vmdb_test'}
    arr << {:type => 'master', :active => true, :host => '203.0.113.2', :user => 'root', :dbname => 'vmdb_test'}
    arr << {:type => 'standby', :active => true, :host => '203.0.113.3', :user => 'root', :dbname => 'vmdb_test'}
  end
end
