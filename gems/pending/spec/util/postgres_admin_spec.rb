require "util/postgres_admin"

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
  end

  describe ".parse_dsn" do
    it "no spaces, no quotes" do
      s = "host=localhost"
      expect(described_class.parse_dsn(s)).to eq(:host => "localhost")
    end

    it "spaces, no quotes" do
      s = "host = localhost"
      expect(described_class.parse_dsn(s)).to eq(:host => "localhost")
    end

    it "no spaces, quotes" do
      s = "host='localhost'"
      expect(described_class.parse_dsn(s)).to eq(:host => "localhost")
    end

    it "spaces, quotes" do
      s = "host = 'localhost'"
      expect(described_class.parse_dsn(s)).to eq(:host => "localhost")
    end

    it "spaces, quotes, space in value" do
      s = "host = 'local host'"
      expect(described_class.parse_dsn(s)).to eq(:host => "local host")
    end

    it "spaces, quotes, quote in value" do
      s = "host = 'local\\'shost\\''"
      expect(described_class.parse_dsn(s)).to eq(:host => "local'shost'")
    end

    it "full dsn quoted" do
      s = "dbname = 'vmdb\\'s_test' host='example.com' user = 'root' port='' password='p=as\\' s\\''"
      expected = {
        :dbname   => "vmdb's_test",
        :host     => "example.com",
        :user     => "root",
        :port     => "",
        :password => "p=as' s'"
      }
      expect(described_class.parse_dsn(s)).to eq(expected)
    end

    it "full dsn unquoted" do
      s = "dbname = vmdb\\'s_test host=example.com user = root password=p=as\\'s\\'"
      expected = {
        :dbname   => "vmdb's_test",
        :host     => "example.com",
        :user     => "root",
        :password => "p=as's'"
      }
      expect(described_class.parse_dsn(s)).to eq(expected)
    end

    it "mixed quoted and unquoted" do
      s = "dbname = vmdb\\'s_test host=example.com user = 'root' port='' password='p=as\\' s\\''"
      expected = {
        :dbname   => "vmdb's_test",
        :host     => "example.com",
        :user     => "root",
        :port     => "",
        :password => "p=as' s'"
      }
      expect(described_class.parse_dsn(s)).to eq(expected)
    end

    it "= with spaces" do
      s = "dbname=vmdb_test host=example.com password='pass = word'"
      expected = {
        :dbname   => "vmdb_test",
        :host     => "example.com",
        :password => "pass = word"
      }
      expect(described_class.parse_dsn(s)).to eq(expected)
    end

    it "leading single quote" do
      s = "dbname=vmdb_test host=example.com password='\\'password'"
      expected = {
        :dbname   => "vmdb_test",
        :host     => "example.com",
        :password => "'password"
      }
      expect(described_class.parse_dsn(s)).to eq(expected)
    end

    it "single quote after =" do
      s = "dbname=vmdb_test host=example.com password='pass =\\' word'"
      expected = {
        :dbname   => "vmdb_test",
        :host     => "example.com",
        :password => "pass =' word"
      }
      expect(described_class.parse_dsn(s)).to eq(expected)
    end
  end
end
