require "spec_helper"

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
end
