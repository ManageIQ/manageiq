require "util/postgres_admin"
require 'pg'

describe PostgresAdmin do
  context "ENV dependent" do
    after do
      ENV.delete_if { |k, _| k.start_with?("APPLIANCE") }
    end

    [%w(pg_ctl             APPLIANCE_PG_CTL             /some/path      true),
     %w(data_directory     APPLIANCE_PG_DATA            /some/path      true),
     %w(service_name       APPLIANCE_PG_SERVICE         postgresql          ),
     %w(scl_name           APPLIANCE_PG_SCL_NAME        postgresql_scl      ),
     %w(package_name       APPLIANCE_PG_PACKAGE_NAME    postgresql-server   ),
     %w(template_directory APPLIANCE_TEMPLATE_DIRECTORY /some/path      true),

    ].each do |method, var, value, pathname_required|
      it "#{method}" do
        ENV[var] = value
        result = described_class.public_send(method)
        if pathname_required
          expect(result.join("abc/def").to_s).to eql "#{value}/abc/def"
        else
          expect(result).to eql value
        end
      end
    end

    it ".scl_enable_prefix" do
      ENV["APPLIANCE_PG_SCL_NAME"] = "postgresql92"
      expect(described_class.scl_enable_prefix).to eql "scl enable postgresql92"
    end

    it ".start_command" do
      ENV["APPLIANCE_PG_SERVICE"] = "postgresql"
      expect(described_class.start_command).to eql "service postgresql start"
    end

    it ".logical_volume_path" do
      expect(described_class.logical_volume_path.to_s).to eql "/dev/vg_data/lv_pg"
    end

    context ".stop_command" do
      before do
        ENV["APPLIANCE_PG_CTL"]  = "/ctl/path"
        ENV["APPLIANCE_PG_DATA"] = "/pgdata/path"
      end

      it "graceful" do
        expect(described_class.stop_command(true))
          .to eql "su - postgres -c '/ctl/path stop -W -D /pgdata/path -s -m smart'"
      end

      it "fast" do
        expect(described_class.stop_command(false))
          .to eql "su - postgres -c '/ctl/path stop -W -D /pgdata/path -s -m fast'"
      end
    end

    describe ".initialized?" do
      around do |example|
        Dir.mktmpdir do |dir|
          ENV["APPLIANCE_PG_DATA"] = dir
          example.run
        end
      end

      it "returns true with files in the data directory" do
        FileUtils.touch("#{ENV["APPLIANCE_PG_DATA"]}/somefile")
        expect(described_class.initialized?).to be true
      end

      it "returns false without files in the data directory" do
        expect(described_class.initialized?).to be false
      end
    end
  end

  describe ".database_in_recovery?" do
    before do
      begin
        @connection = PG::Connection.open(:dbname => 'travis', :user => 'travis')
      rescue PG::ConnectionBad
        skip "travis database does not exist"
      end
    end

    after do
      @connection.finish if @connection
    end

    it "returns false if postgres database not in recovery mode" do
      expect(described_class.database_in_recovery?(@connection)).to be false
    end
  end
end
