describe EmbeddedAnsibleWorker::Runner do
  context ".new" do
    let(:miq_server)  {
      s = EvmSpecHelper.create_guid_miq_server_zone[1]
      s.update(:hostname => "fancyserver")
      s
    }
    let(:worker_guid) { MiqUUID.new_guid }
    let(:worker)      { FactoryGirl.create(:embedded_ansible_worker, :guid => worker_guid, :miq_server_id => miq_server.id) }
    let(:runner) {
      worker
      allow_any_instance_of(described_class).to receive(:worker_initialization)
      described_class.new(:guid => worker_guid)
    }

    context "#update_embedded_ansible_provider" do
      before do
        EvmSpecHelper.local_guid_miq_server_zone
        MiqDatabase.seed
        MiqDatabase.first.ansible_admin_password = "secret"
      end

      it "creates initial" do
        runner.update_embedded_ansible_provider

        provider = ManageIQ::Providers::EmbeddedAnsible::Provider.first
        expect(provider.zone).to eq(miq_server.zone)
        expect(provider.default_endpoint.url).to eq("https://fancyserver/ansibleapi/v1")
        userid, password = provider.auth_user_pwd
        expect(userid).to eq("admin")
        expect(password).to eq("secret")
      end

      it "updates existing" do
        runner.update_embedded_ansible_provider
        new_zone = FactoryGirl.create(:zone)
        miq_server.update(:hostname => "boringserver", :zone => new_zone)

        runner.update_embedded_ansible_provider
        expect(ManageIQ::Providers::EmbeddedAnsible::Provider.count).to eq(1)

        provider = ManageIQ::Providers::EmbeddedAnsible::Provider.first
        expect(provider.zone).to eq(new_zone)
        expect(provider.default_endpoint.url).to eq("https://boringserver/ansibleapi/v1")
      end
    end
  end
end

