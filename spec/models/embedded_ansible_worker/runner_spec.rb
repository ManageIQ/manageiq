describe EmbeddedAnsibleWorker::Runner do
  let(:embedded_ansible_instance) { double("EmbeddedAnsible") }
  before do
    allow(EmbeddedAnsible).to receive(:new).and_return(embedded_ansible_instance)
  end

  context ".new" do
    let(:miq_server)  {
      s = EvmSpecHelper.create_guid_miq_server_zone[1]
      s.update(:hostname => "fancyserver")
      s
    }
    let(:worker_guid) { SecureRandom.uuid }
    let(:worker)      { FactoryGirl.create(:embedded_ansible_worker, :guid => worker_guid, :miq_server_id => miq_server.id) }
    let(:runner) {
      worker
      allow_any_instance_of(described_class).to receive(:worker_initialization)
      r = described_class.new(:guid => worker_guid)
      allow(r).to receive(:worker).and_return(worker)
      r
    }

    context "#do_before_work_loop" do
      let(:start_notification_id) { NotificationType.find_by(:name => "role_activate_start").id }
      let(:success_notification_id) { NotificationType.find_by(:name => "role_activate_success").id }

      before do
        ServerRole.seed
        NotificationType.seed
      end

      it "creates a notification to inform the user that the service has started" do
        expect(runner).to receive(:setup_ansible)
        expect(runner).to receive(:update_embedded_ansible_provider)

        runner.do_before_work_loop

        note = Notification.find_by(:notification_type_id => success_notification_id)
        expect(note.options[:role_name]).to eq("Embedded Ansible")
        expect(note.options.keys).to include(:server_name)
      end

      it "creates a notification to inform the user that the role has been assigned" do
        expect(runner).to receive(:setup_ansible)
        expect(runner).to receive(:update_embedded_ansible_provider)

        runner.do_before_work_loop

        note = Notification.find_by(:notification_type_id => start_notification_id)
        expect(note.options[:role_name]).to eq("Embedded Ansible")
        expect(note.options.keys).to include(:server_name)
      end

      it "exits on exceptions" do
        expect(runner).to receive(:setup_ansible)
        expect(runner).to receive(:update_embedded_ansible_provider).and_raise(StandardError)
        expect(runner).to receive(:do_exit)
        runner.do_before_work_loop
      end
    end

    context "#update_embedded_ansible_provider" do
      let(:api_connection) { double("AnsibleAPIConnection") }
      before do
        EvmSpecHelper.local_miq_server
        MiqDatabase.seed
        MiqDatabase.first.set_ansible_admin_authentication(:password => "secret")

        allow(embedded_ansible_instance).to receive(:api_connection).and_return(api_connection)
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

      context "in a container" do
        before do
          expect(MiqEnvironment::Command).to receive(:is_container?).and_return(true)
        end

        it "creates the provider with the service name for the URL" do
          expect(worker).to receive(:remove_demo_data).with(api_connection)
          expect(worker).to receive(:ensure_initial_objects)
            .with(instance_of(ManageIQ::Providers::EmbeddedAnsible::Provider), api_connection)

          runner.update_embedded_ansible_provider

          provider = ManageIQ::Providers::EmbeddedAnsible::Provider.first
          expect(provider.zone).to eq(miq_server.zone)
          expect(provider.default_endpoint.url).to eq("https://ansible/api/v1")
          userid, password = provider.auth_user_pwd
          expect(userid).to eq("admin")
          expect(password).to eq("secret")
        end
      end
    end

    context "#do_work" do
      it "starts embedded ansible if it is not alive and not running" do
        allow(embedded_ansible_instance).to receive(:alive?).and_return(false)
        allow(embedded_ansible_instance).to receive(:running?).and_return(false)

        expect(embedded_ansible_instance).to receive(:start)

        runner.do_work
      end

      context "with a provider" do
        let(:provider) { FactoryGirl.create(:provider_embedded_ansible, :with_authentication) }

        it "runs an authentication check if embedded ansible is alive and the credentials are not valid" do
          auth = provider.authentications.first
          auth.status = "Error"
          auth.save!

          allow(embedded_ansible_instance).to receive(:alive?).and_return(true)
          allow(runner).to receive(:provider).and_return(provider)
          expect(provider).to receive(:authentication_check)

          runner.do_work
        end

        it "doesn't run an authentication check if the credentials are valid" do
          allow(embedded_ansible_instance).to receive(:alive?).and_return(true)
          allow(runner).to receive(:provider).and_return(provider)
          expect(provider).not_to receive(:authentication_check)

          runner.do_work
        end
      end
    end
  end
end
