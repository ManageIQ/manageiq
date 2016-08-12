require 'postgres_ha_admin/failover_monitor'
require 'util/postgres_admin'

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

  let(:linux_admin) do
    linux_adm = double('LinuxAdmin')
    allow(LinuxAdmin::Service).to receive(:new).and_return(linux_adm)
    linux_adm
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
        expect(failover_db).to receive(:update_failover_yml)
        failover_monitor.monitor
      end

      it "does not stop evm server and does not execute failover" do
        expect(failover_db).to receive(:update_failover_yml)
        expect(linux_admin).not_to receive(:stop)
        expect(linux_admin).not_to receive(:restart)
        expect(failover_monitor).not_to receive(:execute_failover)

        failover_monitor.monitor
      end
    end

    context "primary database is not accessable" do
      before do
        allow(PG::Connection).to receive(:open).and_return(nil, connection, connection)
      end

      describe "#host_is_repmgr_primary?" do
        it "return true if supplied connection established with primary database" do
          expect(failover_db).to receive(:query_repmgr).and_return(guery_repmanager_result)
          expect(failover_monitor.host_is_repmgr_primary?('203.0.113.2', connection)).to be true
        end

        it "return false if supplied connection established with not primary database" do
          expect(failover_db).to receive(:query_repmgr).and_return(guery_repmanager_result)
          expect(failover_monitor.host_is_repmgr_primary?('203.0.113.3', connection)).to be false
        end
      end

      it "stop evm server(if it is running) before failover attempt" do
        expect(linux_admin).to receive(:stop).ordered
        expect(failover_monitor).to receive(:execute_failover).ordered

        failover_monitor.monitor
      end

      it "does not update 'database.yml' and 'failover_databases.yml' if all standby DBs are in recovery mode" do
        expect(failover_db).to receive(:active_databases).and_return(active_databases_list)
        expect(failover_db).not_to receive(:update_database_yml)
        expect(db_yml).not_to receive(:update_database_yml)
        expect(linux_admin).not_to receive(:restart)

        expect(failover_monitor).to receive(:stop_evmserverd).ordered
        expect(PostgresAdmin).to receive(:database_in_recovery?).and_return(true, true, true).ordered

        stub_const("PostgresHaAdmin::FailoverMonitor::FAILOVER_ATTEMPTS", 1)
        stub_const("PostgresHaAdmin::FailoverMonitor::FAILOVER_CHECK_FREQUENCY", 1)
        failover_monitor.monitor
      end

      it "does not update 'database.yml' and 'failover_databases.yml' if there is no master database avaiable" do
        expect(failover_db).to receive(:active_databases).and_return(active_databases_list)
        expect(failover_db).not_to receive(:update_database_yml)
        expect(db_yml).not_to receive(:update_database_yml)
        expect(linux_admin).not_to receive(:restart)

        expect(PostgresAdmin).to receive(:database_in_recovery?).and_return(false, false, false)
        expect(linux_admin).to receive(:stop).ordered
        expect(failover_db).to receive(:query_repmgr).and_return(no_master_db_list,
                                                                 no_master_db_list,
                                                                 no_master_db_list).ordered

        stub_const("PostgresHaAdmin::FailoverMonitor::FAILOVER_ATTEMPTS", 1)
        stub_const("PostgresHaAdmin::FailoverMonitor::FAILOVER_CHECK_FREQUENCY", 1)
        failover_monitor.monitor
      end

      it "updates 'database.yml' and 'failover_databases.yml' and restart evm server if new primary db available" do
        allow(PostgresAdmin).to receive(:database_in_recovery?).and_return(false)
        allow(failover_db).to receive(:query_repmgr).and_return(guery_repmanager_result)
        allow(failover_db).to receive(:active_databases).and_return(active_databases_list)
        allow(failover_db).to receive(:update_failover_yml).with(connection)

        expect(linux_admin).to receive(:stop).ordered
        expect(db_yml).to receive(:update_database_yml).ordered
        expect(linux_admin).to receive(:restart).ordered

        stub_const("PostgresHaAdmin::FailoverMonitor::FAILOVER_ATTEMPTS", 1)
        stub_const("PostgresHaAdmin::FailoverMonitor::FAILOVER_CHECK_FREQUENCY", 1)
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

  def no_master_db_list
    arr = []
    arr << {:type => 'standby', :active => false, :host => '203.0.113.1', :user => 'root', :dbname => 'vmdb_test'}
    arr << {:type => 'standby', :active => true, :host => '203.0.113.2', :user => 'root', :dbname => 'vmdb_test'}
    arr << {:type => 'standby', :active => true, :host => '203.0.113.3', :user => 'root', :dbname => 'vmdb_test'}
  end
end
