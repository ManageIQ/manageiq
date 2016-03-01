require_migration

describe MoveLogCollectionDepotSettingsToFileDepot do
  let(:authentication_stub) { migration_stub(:Authentication) }
  let(:configuration_stub) { migration_stub(:Configuration) }
  let(:file_depot_stub) { migration_stub(:FileDepot) }
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

      expect(authentication_stub.count).to eq(2)
      expect(configuration_stub.count).to  eq(1)
      expect(file_depot_stub.count).to     eq(2)
      expect(zone_stub.count).to           eq(1)

      expect(configuration_stub.first.settings).to be_blank
      expect(zone_stub.first.settings).to          be_blank
    end
  end
end
