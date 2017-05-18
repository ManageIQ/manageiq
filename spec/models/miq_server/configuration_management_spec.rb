describe MiqServer, "::ConfigurationManagement" do
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

    describe "#settings_for_resource" do
      it "returns the resource's settings" do
        settings = {:some_thing => [1, 2, 3]}
        stub_settings(settings)
        expect(miq_server.settings_for_resource.to_hash).to eq(settings)
      end
    end

    describe "#add_settings_for_resource" do
      it "sets the specified settings" do
        settings = {:some_test_setting => {:setting => 1}}
        expect(miq_server).to receive(:reload_all_server_settings)

        miq_server.add_settings_for_resource(settings)

        expect(Vmdb::Settings.for_resource(miq_server).some_test_setting.setting).to eq(1)
      end
    end

    describe "#reload_all_server_settings" do
      it "queues #reload_settings for the started servers" do
        FactoryGirl.create(:miq_server, :status => "started")

        miq_server.reload_all_server_settings

        expect(MiqQueue.count).to eq(1)
        message = MiqQueue.first
        expect(message.instance_id).to eq(miq_server.id)
        expect(message.method_name).to eq("reload_settings")
      end
    end

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
    end
  end
end
