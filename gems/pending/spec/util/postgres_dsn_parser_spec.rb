require 'util/postgres_dsn_parser'

describe PostgresDsnParser do
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
