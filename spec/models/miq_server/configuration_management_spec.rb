describe MiqServer, "::ConfigurationManagement" do
  describe "#settings" do
    shared_examples_for "#settings" do
      it "with no changes in the database" do
        settings = miq_server.settings
        expect(settings).to be_kind_of(Hash)
        expect(settings.fetch_path(:api, :token_ttl)).to eq("10.minutes")
      end

      it "with changes in the database" do
        miq_server.settings_changes = [
          FactoryGirl.create(:settings_change, :key => "/api/token_ttl", :value => "2.minutes")
        ]
        Settings.reload!

        settings = miq_server.settings
        expect(settings).to be_kind_of(Hash)
        expect(settings.fetch_path(:api, :token_ttl)).to eq("2.minutes")
      end
    end

    context "local server" do
      let(:miq_server) { EvmSpecHelper.local_miq_server }

      before { stub_local_settings(miq_server) }

      include_examples "#settings"
    end

    context "remote server" do
      let(:miq_server) { EvmSpecHelper.remote_miq_server }

      before { stub_local_settings(nil) }

      include_examples "#settings"
    end
  end

  describe "#get_config" do
    shared_examples_for "#get_config" do
      it "with no changes in the database" do
        config = miq_server.get_config("vmdb")
        expect(config).to be_kind_of(VMDB::Config)
        expect(config.config.fetch_path(:api, :token_ttl)).to eq("10.minutes")
      end

      it "with changes in the database" do
        miq_server.settings_changes = [
          FactoryGirl.create(:settings_change, :key => "/api/token_ttl", :value => "2.minutes")
        ]
        Settings.reload!

        config = miq_server.get_config("vmdb")
        expect(config).to be_kind_of(VMDB::Config)
        expect(config.config.fetch_path(:api, :token_ttl)).to eq("2.minutes")
      end
    end

    context "local server" do
      let(:miq_server) { EvmSpecHelper.local_miq_server }

      before { stub_local_settings(miq_server) }

      include_examples "#get_config"
    end

    context "remote server" do
      let(:miq_server) { EvmSpecHelper.remote_miq_server }

      before { stub_local_settings(nil) }

      include_examples "#get_config"
    end
  end

  describe "#reload_settings" do
    let(:miq_server) { EvmSpecHelper.local_miq_server }

    it "reloads the new changes into the settings for the resource" do
      Vmdb::Settings.save!(miq_server, :some_test_setting => 2)
      expect(Settings.some_test_setting).to be_nil

      miq_server.reload_settings

      expect(Settings.some_test_setting).to eq(2)
    end
  end

  context "ConfigurationManagementMixin" do
    let(:miq_server) { FactoryGirl.create(:miq_server) }
    describe "#config_activated" do
      let(:zone) { FactoryGirl.create(:zone, :name => "My Zone") }
      let(:zone_other_region) do
        other_region_id = ApplicationRecord.id_in_region(1, MiqRegion.my_region_number + 1)
        FactoryGirl.create(:zone, :id => other_region_id).tap do |z|
          z.update_column(:name, "My Zone") # Bypass validation for test purposes
        end
      end

      it "saves settings with the zone in the correct region" do
        miq_server = EvmSpecHelper.local_miq_server(:zone => zone)
        zone_other_region

        miq_server.config_activated(OpenStruct.new(:zone => "My Zone"))

        expect(miq_server.reload.zone).to eq(zone)
      end

      it "does not overwrite the servers zone_id if the config value is invalid" do
        _guid, miq_server, zone = EvmSpecHelper.local_guid_miq_server_zone

        miq_server.send(:immediately_reload_settings)

        expect(MiqServer.my_server.zone).to eq(zone)
      end
    end
  end
end
