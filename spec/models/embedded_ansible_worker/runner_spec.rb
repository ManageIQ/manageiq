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
      r = described_class.new(:guid => worker_guid)
      allow(r).to receive(:worker).and_return(worker)
      r
    }

    it "#do_before_work_loop exits on exceptions" do
      expect(runner).to receive(:setup_ansible)
      expect(runner).to receive(:update_embedded_ansible_provider).and_raise(StandardError)
      expect(runner).to receive(:do_exit)
      runner.do_before_work_loop
    end

    context "#update_embedded_ansible_provider" do
      let(:api_connection) { double("AnsibleAPIConnection") }
      before do
        EvmSpecHelper.local_guid_miq_server_zone
        MiqDatabase.seed
        MiqDatabase.first.set_ansible_admin_authentication(:password => "secret")

        allow(EmbeddedAnsible).to receive(:api_connection).and_return(api_connection)
      end

      it "creates initial" do
        expect(worker).to receive(:remove_demo_data).with(api_connection)
        expect(worker).to receive(:ensure_initial_objects)
          .with(instance_of(ManageIQ::Providers::EmbeddedAnsible::Provider), api_connection)

        runner.update_embedded_ansible_provider

        provider = ManageIQ::Providers::EmbeddedAnsible::Provider.first
        expect(provider.zone).to eq(miq_server.zone)
        expect(provider.default_endpoint.url).to eq("https://fancyserver/ansibleapi/v1")
        userid, password = provider.auth_user_pwd
        expect(userid).to eq("admin")
        expect(password).to eq("secret")
      end

      it "updates existing" do
        expect(worker).to receive(:remove_demo_data).twice.with(api_connection)
        expect(worker).to receive(:ensure_initial_objects).twice
          .with(instance_of(ManageIQ::Providers::EmbeddedAnsible::Provider), api_connection)

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

    context "#setup_ansible" do
      it "configures EmbeddedAnsible if it is not configured" do
        expect(EmbeddedAnsible).to receive(:start)

        expect(EmbeddedAnsible).to receive(:configured?).and_return(false)
        expect(EmbeddedAnsible).to receive(:configure)

        runner.setup_ansible
      end

      it "doesn't call configure if EmbeddedAnsible is already configured" do
        expect(EmbeddedAnsible).to receive(:start)

        expect(EmbeddedAnsible).to receive(:configured?).and_return(true)
        expect(EmbeddedAnsible).not_to receive(:configure)

        runner.setup_ansible
      end
    end
  end
end
