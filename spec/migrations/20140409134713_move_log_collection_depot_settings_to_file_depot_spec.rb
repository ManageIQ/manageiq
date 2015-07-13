require "spec_helper"
require Rails.root.join("db/migrate/20140409134713_move_log_collection_depot_settings_to_file_depot")

describe MoveLogCollectionDepotSettingsToFileDepot do
  let(:configuration_stub) { migration_stub(:Configuration) }
  let(:zone_stub) { migration_stub(:Zone) }

  migration_context :up do
    it "Moves log depot settings to FileDepot table" do
      server_settings = {
        "log_depot" => {
          "username" => "user",
          "password" => "pass",
          "uri"      => "ftp://ftp.example.com/dir"
        }
      }

      zone_settings = {
        :log_depot => {
          :username => "user",
          :password => "pass",
          :uri      => "smb://server.example.com/path"
        }
      }

      configuration_stub.create!(:typ => 'vmdb', :settings => server_settings)
      zone_stub.create!(:name => "default", :settings => zone_settings)

      migrate

      expect(Authentication.count).to eq(2)
      expect(Configuration.count).to  eq(1)
      expect(FileDepot.count).to      eq(2)
      expect(Zone.count).to           eq(1)

      expect(Configuration.first.settings).to be_blank
      expect(Zone.first.settings).to          be_blank
    end
  end
end
