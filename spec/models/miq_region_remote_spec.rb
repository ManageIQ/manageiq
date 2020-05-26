RSpec.describe MiqRegionRemote do
  describe ".validate_connection_settings" do
    it "returns a message about indicating the port is missing when blank" do
      host = "192.0.2.1"
      port = nil
      username = "foo"
      password = "bar"

      actual = described_class.validate_connection_settings(host, port, username, password)

      expect(actual).to include("Validation failed due to missing port")
    end
  end

  describe ".with_remote_connection" do
    it "removes the temporary connection pool" do
      original = described_class.connection.raw_connection.conninfo_hash[:dbname]

      config = ActiveRecord::Base.configurations[Rails.env]
      params = config.values_at("host", "port", "username", "password", "database", "adapter")
      params[0] ||= "localhost"
      params[4]   = "template1"

      described_class.with_remote_connection(*params) do |c|
        expect(c.raw_connection.conninfo_hash[:dbname]).to eq("template1")
        expect(described_class.connection.raw_connection.conninfo_hash[:dbname]).to eq("template1")
      end

      expect(described_class.connection.raw_connection.conninfo_hash[:dbname]).to eq(original)
    end
  end
end
