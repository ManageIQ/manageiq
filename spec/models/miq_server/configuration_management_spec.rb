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

        config = miq_server.get_config("vmdb")
        expect(config).to be_kind_of(VMDB::Config)
        expect(config.config.fetch_path(:api, :token_ttl)).to eq("2.minutes")
      end
    end

    context "local server" do
      let(:miq_server) { EvmSpecHelper.local_miq_server }

      include_examples "#get_config"
    end

    context "remote server" do
      let(:miq_server) { EvmSpecHelper.remote_miq_server }

      include_examples "#get_config"
    end
  end
end
