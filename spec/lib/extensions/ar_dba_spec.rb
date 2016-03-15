describe "ar_dba extension" do
  let(:connection) { ApplicationRecord.connection }

  describe "#primary_key?" do
    it "returns false for a table without a primary key" do
      table_name = "no_pk_test"
      connection.select_value("CREATE TABLE #{table_name} (id INTEGER)")
      expect(connection.primary_key?(table_name)).to be false
    end

    it "returns true for a table with a primary key" do
      expect(connection.primary_key?("miq_databases")).to be true
    end

    it "returns true for composite primary keys" do
      expect(connection.primary_key?("storages_vms_and_templates")).to be true
    end
  end

  describe "#parse_dsn" do
    it "no spaces, no quotes" do
      s = "host=localhost"
      expect(connection.class.parse_dsn(s)).to eq(:host => "localhost")
    end

    it "spaces, no quotes" do
      s = "host = localhost"
      expect(connection.class.parse_dsn(s)).to eq(:host => "localhost")
    end

    it "no spaces, quotes" do
      s = "host='localhost'"
      expect(connection.class.parse_dsn(s)).to eq(:host => "localhost")
    end

    it "spaces, quotes" do
      s = "host = 'localhost'"
      expect(connection.class.parse_dsn(s)).to eq(:host => "localhost")
    end

    it "spaces, quotes, space in value" do
      s = "host = 'local host'"
      expect(connection.class.parse_dsn(s)).to eq(:host => "local host")
    end

    it "spaces, quotes, quote in value" do
      s = "host = 'local\\'shost\\''"
      expect(connection.class.parse_dsn(s)).to eq(:host => "local'shost'")
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
      expect(connection.class.parse_dsn(s)).to eq(expected)
    end

    it "full dsn unquoted" do
      s = "dbname = vmdb\\'s_test host=example.com user = root password=p=as\\'s\\'"
      expected = {
        :dbname   => "vmdb's_test",
        :host     => "example.com",
        :user     => "root",
        :password => "p=as's'"
      }
      expect(connection.class.parse_dsn(s)).to eq(expected)
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
      expect(connection.class.parse_dsn(s)).to eq(expected)
    end

    it "= with spaces" do
      s = "dbname=vmdb_test host=example.com password='pass = word'"
      expected = {
        :dbname   => "vmdb_test",
        :host     => "example.com",
        :password => "pass = word"
      }
      expect(connection.class.parse_dsn(s)).to eq(expected)
    end

    it "leading single quote" do
      s = "dbname=vmdb_test host=example.com password='\\'password'"
      expected = {
        :dbname   => "vmdb_test",
        :host     => "example.com",
        :password => "'password"
      }
      expect(connection.class.parse_dsn(s)).to eq(expected)
    end

    it "single quote after =" do
      s = "dbname=vmdb_test host=example.com password='pass =\\' word'"
      expected = {
        :dbname   => "vmdb_test",
        :host     => "example.com",
        :password => "pass =' word"
      }
      expect(connection.class.parse_dsn(s)).to eq(expected)
    end
  end
end
