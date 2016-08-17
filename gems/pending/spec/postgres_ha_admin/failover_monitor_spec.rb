require 'postgres_ha_admin/failover_monitor'
require 'util/postgres_admin'

describe PostgresHaAdmin::FailoverMonitor do
  let(:db_yml)      { double('DatabaseYml') }
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
    before do
      params = {
        :host     => 'host.example.com',
        :user     => 'root',
        :password => 'password'
      }
      allow(db_yml).to receive(:pg_params_from_database_yml).and_return(params)
    end

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
        stub_monitor_constants
      end

      it "stop evm server(if it is running) before failover attempt" do
        expect(linux_admin).to receive(:stop).ordered
        expect(failover_monitor).to receive(:execute_failover).ordered
        failover_monitor.monitor
      end

      it "does not update 'database.yml' and 'failover_databases.yml' if all standby DBs are in recovery mode" do
        failover_not_executed
        expect(PostgresAdmin).to receive(:database_in_recovery?).and_return(true, true, true).ordered
        failover_monitor.monitor
      end

      it "does not update 'database.yml' and 'failover_databases.yml' if there is no master database avaiable" do
        failover_not_executed
        expect(PostgresAdmin).to receive(:database_in_recovery?).and_return(false, false, false).ordered
        expect(failover_db).to receive(:host_is_repmgr_primary?).and_return(false, false, false).ordered
        failover_monitor.monitor
      end

      it "updates 'database.yml' and 'failover_databases.yml' and restart evm server if new primary db available" do
        failover_executed
        expect(PostgresAdmin).to receive(:database_in_recovery?).and_return(false)
        expect(failover_db).to receive(:host_is_repmgr_primary?).and_return(true)
        failover_monitor.monitor
      end
    end
  end

  describe "#active_servers_conninfo" do
    it "merges settings from database yml and failover yml" do
      active_servers_conninfo = [
        {:host => 'failover_host.example.com'},
        {:host => 'failover_host2.example.com'}
      ]
      expected_conninfo = [
        {:host => 'failover_host.example.com', :password => 'mypassword'},
        {:host => 'failover_host2.example.com', :password => 'mypassword'}
      ]
      settings_from_db_yml = {:host => 'host.example.com', :password => 'mypassword'}
      expect(failover_db).to receive(:active_databases_conninfo_hash).and_return(active_servers_conninfo)
      expect(db_yml).to receive(:pg_params_from_database_yml).and_return(settings_from_db_yml)
      expect(failover_monitor.active_servers_conninfo).to match_array(expected_conninfo)
    end
  end

  def failover_executed
    expect(linux_admin).to receive(:stop)
    expect(failover_db).to receive(:active_databases_conninfo_hash).and_return(active_databases_conninfo)
    expect(failover_db).to receive(:update_failover_yml)
    expect(db_yml).to receive(:update_database_yml)
    expect(linux_admin).to receive(:restart)
  end

  def failover_not_executed
    expect(linux_admin).to receive(:stop)
    expect(failover_db).to receive(:active_databases_conninfo_hash).and_return(active_databases_conninfo)
    expect(failover_db).not_to receive(:update_failover_yml)
    expect(db_yml).not_to receive(:update_database_yml)
    expect(linux_admin).not_to receive(:restart)
  end

  def stub_monitor_constants
    stub_const("PostgresHaAdmin::FailoverMonitor::FAILOVER_ATTEMPTS", 1)
    stub_const("PostgresHaAdmin::FailoverMonitor::FAILOVER_CHECK_FREQUENCY", 1)
  end

  def active_databases_conninfo
    arr = []
    arr << {:host => '203.0.113.1', :user => 'root', :dbname => 'vmdb_test'}
    arr << {:host => '203.0.113.2', :user => 'root', :dbname => 'vmdb_test'}
    arr << {:host => '203.0.113.3', :user => 'root', :dbname => 'vmdb_test'}
  end
end
