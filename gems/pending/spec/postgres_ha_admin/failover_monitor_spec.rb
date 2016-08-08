require 'postgres_ha_admin/failover_monitor'

describe PostgresHaAdmin::FailoverMonitor do
  let(:db_yml) do
    yml = double(PostgresHaAdmin::DatabaseYml)
    allow(yml).to receive(:pg_params_from_database_yml).and_return(:host => 'host.example.com', :user => 'root')
    yml
  end
  let(:failover_db) { double(PostgresHaAdmin::FailoverDatabases) }
  let(:connection) { double("PGConnection") }

  let(:ha_admin) do
    expect(PostgresHaAdmin::DatabaseYml).to receive(:new).and_return(db_yml)
    expect(PostgresHaAdmin::FailoverDatabases).to receive(:new).and_return(failover_db)
    described_class.new('', '', @logger_file.path, 'test')
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
        allow(connection).to receive(:finish)
      end

      it "updates 'failover_databases.yml'" do
        expect(failover_db).to receive(:update_failover_yml).with(connection)
        ha_admin.monitor
      end

      it "does not stop evm server" do

      end

      it "does not execute failover" do

      end
    end
  end
end
