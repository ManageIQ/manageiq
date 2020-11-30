RSpec.describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Credential do
  let(:embedded_ansible) { ManageIQ::Providers::EmbeddedAnsible::AutomationManager }
  let(:manager) do
    FactoryBot.create(:provider_embedded_ansible, :default_organization => 1).managers.first
  end

  before do
    EvmSpecHelper.assign_embedded_ansible_role
  end

  context "#native_ref" do
    let(:simple_credential) { described_class.new(:manager_ref => '1', :resource => manager) }

    it "returns integer" do
      expect(simple_credential.manager_ref).to eq('1')
      expect(simple_credential.native_ref).to eq(1)
    end

    it "blows up for nil manager_ref" do
      simple_credential.manager_ref = nil
      expect(simple_credential.manager_ref).to be_nil
      expect { simple_credential.native_ref }.to raise_error(TypeError)
    end
  end

  shared_examples_for "an embedded_ansible credential" do
    let(:base_excludes) { [:password, :auth_key, :service_account] }

    context "CREATE" do
      it ".create_in_provider creates a record" do
        create_params = params_to_attributes.merge(:resource => manager)
        expect(credential_class).to receive(:create!).with(create_params).and_call_original
        expect(Notification).to     receive(:create!).never

        record = credential_class.create_in_provider(manager.id, params)

        expect(record).to be_a(credential_class)
        expect(record.manager).to eq(manager)
        expected_values.each do |attr, val|
          expect(record.send(attr)).to eq(val)
        end
      end

      it ".create_in_provider can create with `nil` options" do
        keys_to_remove  = params_to_attributes.fetch(:options, {}).keys
        passed_params   = params.except(*keys_to_remove)

        params_to_attributes.delete(:options)
        params_to_attributes.merge!(:resource => manager)
        expected_values.delete(:options)
        keys_to_remove.each { |key| expected_values[key] = nil }

        expect(credential_class).to receive(:create!).with(params_to_attributes).and_call_original
        expect(Notification).to     receive(:create!).never

        record = credential_class.create_in_provider(manager.id, passed_params)

        expect(record).to be_a(credential_class)
        expect(record.manager).to eq(manager)
        expected_values.each do |attr, val|
          expect(record.send(attr)).to eq(val)
        end
      end

      it ".create_in_provider_queue queues a create task" do
        task_id       = credential_class.create_in_provider_queue(manager.id, params)
        expected_name = "Creating #{described_class::FRIENDLY_NAME} (name=#{params[:name]})"
        expect(MiqTask.find(task_id)).to have_attributes(:name => expected_name)
        expect(MiqQueue.first).to have_attributes(
          :args        => [manager.id, queue_create_params],
          :class_name  => credential_class.name,
          :method_name => "create_in_provider",
          :priority    => MiqQueue::HIGH_PRIORITY,
          :role        => "embedded_ansible",
          :zone        => nil
        )
      end

      it ".create_in_provider_queue will fail with incompatible manager" do
        wrong_manager = FactoryBot.create(:configuration_manager_foreman)
        expect { credential_class.create_in_provider_queue(wrong_manager.id, params) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "UPDATE" do
      let(:ansible_cred) { credential_class.raw_create_in_provider(manager, params) }

      it "#update_in_provider to succeed" do
        expect(Notification).to receive(:create!).never

        previous_params_to_attrs = params_to_attrs.each_with_object({}) do |key, attrs|
                                     attrs[key] = ansible_cred.send(key)
                                   end

        result = ansible_cred.update_in_provider update_params

        expect(result).to be_a(credential_class)
        expect(result.name).to eq("Updated Credential")

        # Doesn't muck up old attrs
        previous_params_to_attrs.each do |attr, value|
          expect(result.send(attr)).to eq(value)
        end
      end

      it "#update_in_provider_queue" do
        task_id   = ansible_cred.update_in_provider_queue(update_params)
        task_name = "Updating #{described_class::FRIENDLY_NAME} (name=#{ansible_cred.name})"

        update_queue_params[:task_id] = task_id

        expect(MiqTask.find(task_id)).to have_attributes(:name => task_name)
        expect(MiqQueue.first).to have_attributes(
          :instance_id => ansible_cred.id,
          :args        => [update_queue_params],
          :class_name  => credential_class.name,
          :method_name => "update_in_provider",
          :priority    => MiqQueue::HIGH_PRIORITY,
          :role        => "embedded_ansible",
          :zone        => nil
        )
      end
    end

    context "DELETE" do
      let(:ansible_cred) { credential_class.raw_create_in_provider(manager, params) }

      it "#delete_in_provider will delete the record" do
        expect(Notification).to receive(:create!).never
        ansible_cred.delete_in_provider
      end

      it "#delete_in_provider_queue will queue a a delete task" do
        task_id   = ansible_cred.delete_in_provider_queue
        task_name = "Deleting #{described_class::FRIENDLY_NAME} (name=#{ansible_cred.name})"

        expect(MiqTask.find(task_id)).to have_attributes(:name => task_name)
        expect(MiqQueue.first).to have_attributes(
          :instance_id => ansible_cred.id,
          :args        => [],
          :class_name  => credential_class.name,
          :method_name => "delete_in_provider",
          :priority    => MiqQueue::HIGH_PRIORITY,
          :role        => "embedded_ansible",
          :zone        => nil
        )
      end
    end
  end

  context "MachineCredential" do
    let(:credential_class) { embedded_ansible::MachineCredential }
    let(:expected_ssh_key) { "secret2\n" }

    let(:params) do
      {
        :name            => "Machine Credential",
        :userid          => "userid",
        :password        => "secret1",
        :ssh_key_data    => passed_in_ssh_key,
        :become_method   => "sudo",
        :become_password => "secret3",
        :become_username => "admin",
        :ssh_key_unlock  => "secret4"
      }
    end
    let(:queue_create_params) do
      {
        :name            => "Machine Credential",
        :userid          => "userid",
        :password        => ManageIQ::Password.encrypt("secret1"),
        :ssh_key_data    => ManageIQ::Password.encrypt(passed_in_ssh_key),
        :become_method   => "sudo",
        :become_password => ManageIQ::Password.encrypt("secret3"),
        :become_username => "admin",
        :ssh_key_unlock  => ManageIQ::Password.encrypt("secret4")
      }
    end
    let(:params_to_attributes) do
      {
        :name              => "Machine Credential",
        :userid            => "userid",
        :password          => "secret1",
        :auth_key          => passed_in_ssh_key,
        :become_password   => "secret3",
        :become_username   => "admin",
        :auth_key_password => "secret4",
        :options           => {
          :become_method => "sudo"
        }
      }
    end
    let(:expected_values) do
      {
        :name                        => "Machine Credential",
        :userid                      => "userid",
        :password                    => "secret1",
        :ssh_key_data                => expected_ssh_key,
        :become_password             => "secret3",
        :become_username             => "admin",
        :become_method               => "sudo",
        :auth_key_password           => "secret4",
        :password_encrypted          => ManageIQ::Password.try_encrypt("secret1"),
        :auth_key_encrypted          => expected_ssh_key.present? ? ManageIQ::Password.try_encrypt(expected_ssh_key) : expected_ssh_key,
        :become_password_encrypted   => ManageIQ::Password.try_encrypt("secret3"),
        :auth_key_password_encrypted => ManageIQ::Password.try_encrypt("secret4"),
        :options                     => {
          :become_method => "sudo"
        }
      }
    end
    let(:params_to_attrs) { [:auth_key, :auth_key_password, :become_method] }
    let(:update_params) do
      {
        :name     => "Updated Credential",
        :password => "supersecret"
      }
    end
    let(:update_queue_params) do
      {
        :name     => "Updated Credential",
        :password => ManageIQ::Password.encrypt("supersecret")
      }
    end

    context "with an SSH key that ends with a newline" do
      let(:passed_in_ssh_key) { "secret2\n" }

      it_behaves_like 'an embedded_ansible credential'
    end

    context "with an SSH key that does not end with a newline" do
      let(:passed_in_ssh_key) { "secret2" }

      it_behaves_like 'an embedded_ansible credential'
    end

    context "with an nil SSH key" do
      let(:passed_in_ssh_key) { nil }
      let(:expected_ssh_key)  { nil }

      it_behaves_like 'an embedded_ansible credential'
    end

    context "with a empty string SSH key" do
      let(:passed_in_ssh_key) { "" }
      let(:expected_ssh_key)  { "" }

      it_behaves_like 'an embedded_ansible credential'
    end
  end

  context "NetworkCredential" do
    it_behaves_like 'an embedded_ansible credential' do
      let(:credential_class) { embedded_ansible::NetworkCredential }

      let(:params) do
        {
          :name               => "Network Credential",
          :userid             => "userid",
          :password           => "secret1",
          :authorize          => "true",
          :ssh_key_data       => "secret2",
          :authorize_password => "secret3",
          :ssh_key_unlock     => "secret4"
        }
      end
      let(:queue_create_params) do
        {
          :name               => "Network Credential",
          :userid             => "userid",
          :password           => ManageIQ::Password.encrypt("secret1"),
          :authorize          => "true",
          :ssh_key_data       => ManageIQ::Password.encrypt("secret2"),
          :authorize_password => ManageIQ::Password.encrypt("secret3"),
          :ssh_key_unlock     => ManageIQ::Password.encrypt("secret4")
        }
      end
      let(:params_to_attributes) do
        {
          :name              => "Network Credential",
          :userid            => "userid",
          :password          => "secret1",
          :auth_key          => "secret2",
          :become_password   => "secret3",
          :auth_key_password => "secret4",
          :options           => {
            :authorize => "true",
          }
        }
      end
      let(:expected_values) do
        {
          :name                        => "Network Credential",
          :userid                      => "userid",
          :password                    => "secret1",
          :authorize                   => "true",
          :ssh_key_data                => "secret2",
          :authorize_password          => "secret3",
          :ssh_key_unlock              => "secret4",
          :password_encrypted          => ManageIQ::Password.try_encrypt("secret1"),
          :auth_key_encrypted          => ManageIQ::Password.try_encrypt("secret2"),
          :become_password_encrypted   => ManageIQ::Password.try_encrypt("secret3"),
          :auth_key_password_encrypted => ManageIQ::Password.try_encrypt("secret4"),
          :options                     => {
            :authorize => "true"
          }
        }
      end
      let(:params_to_attrs) { [:authorize, :auth_key, :auth_key_password, :become_password] }
      let(:update_params) do
        {
          :name     => "Updated Credential",
          :password => "supersecret"
        }
      end
      let(:update_queue_params) do
        {
          :name     => "Updated Credential",
          :password => ManageIQ::Password.encrypt("supersecret")
        }
      end
    end
  end

  context "ScmCredential" do
    let(:credential_class) { embedded_ansible::ScmCredential }
    let(:expected_ssh_key) { "secret2\n" }

    let(:params) do
      {
        :name           => "Scm Credential",
        :userid         => "userid",
        :password       => "secret1",
        :ssh_key_data   => passed_in_ssh_key,
        :ssh_key_unlock => "secret3"
      }
    end
    let(:queue_create_params) do
      {
        :name           => "Scm Credential",
        :userid         => "userid",
        :password       => ManageIQ::Password.encrypt("secret1"),
        :ssh_key_data   => ManageIQ::Password.encrypt(passed_in_ssh_key),
        :ssh_key_unlock => ManageIQ::Password.encrypt("secret3")
      }
    end
    let(:params_to_attributes) do
      {
        :name              => "Scm Credential",
        :userid            => "userid",
        :password          => "secret1",
        :auth_key          => passed_in_ssh_key,
        :auth_key_password => "secret3",
      }
    end
    let(:expected_values) do
      {
        :name                        => "Scm Credential",
        :userid                      => "userid",
        :password                    => "secret1",
        :ssh_key_data                => expected_ssh_key,
        :ssh_key_unlock              => "secret3",
        :password_encrypted          => ManageIQ::Password.try_encrypt("secret1"),
        :auth_key_encrypted          => expected_ssh_key.present? ? ManageIQ::Password.try_encrypt(expected_ssh_key) : expected_ssh_key,
        :auth_key_password_encrypted => ManageIQ::Password.try_encrypt("secret3")
      }
    end
    let(:params_to_attrs) { [:auth_key, :auth_key_password] }
    let(:update_params) do
      {
        :name     => "Updated Credential",
        :password => "supersecret"
      }
    end
    let(:update_queue_params) do
      {
        :name     => "Updated Credential",
        :password => ManageIQ::Password.encrypt("supersecret")
      }
    end

    context "with an SSH key that ends with a newline" do
      let(:passed_in_ssh_key) { "secret2\n" }

      it_behaves_like 'an embedded_ansible credential'
    end

    context "with an SSH key that does not end with a newline" do
      let(:passed_in_ssh_key) { "secret2" }

      it_behaves_like 'an embedded_ansible credential'
    end

    context "with an nil SSH key" do
      let(:passed_in_ssh_key) { nil }
      let(:expected_ssh_key)  { nil }

      it_behaves_like 'an embedded_ansible credential'
    end

    context "with a empty string SSH key" do
      let(:passed_in_ssh_key) { "" }
      let(:expected_ssh_key)  { "" }

      it_behaves_like 'an embedded_ansible credential'
    end
  end

  context "VaultCredential" do
    it_behaves_like 'an embedded_ansible credential' do
      let(:credential_class)     { embedded_ansible::VaultCredential }
      let(:params_to_attributes) { params.except(:vault_password).merge(:password => "secret1") }

      let(:params) do
        {
          :name           => "Vault Credential",
          :vault_password => "secret1"
        }
      end
      let(:queue_create_params) do
        {
          :name           => "Vault Credential",
          :vault_password => ManageIQ::Password.encrypt("secret1")
        }
      end
      let(:expected_values) do
        {
          :name               => "Vault Credential",
          :vault_password     => "secret1",
          :password_encrypted => ManageIQ::Password.try_encrypt("secret1")
        }
      end
      let(:params_to_attrs) { [:password] }
      let(:update_params) do
        {
          :name           => "Updated Credential",
        }
      end
      let(:update_queue_params) do
        {
          :name           => "Updated Credential",
        }
      end
    end
  end

  context "AmazonCredential" do
    it_behaves_like 'an embedded_ansible credential' do
      let(:credential_class)     { embedded_ansible::AmazonCredential }
      let(:params_to_attributes) { params.except(:security_token).merge(:auth_key => "secret2") }

      let(:params) do
        {
          :name           => "Amazon Credential",
          :userid         => "userid",
          :password       => "secret1",
          :security_token => "secret2",
        }
      end
      let(:queue_create_params) do
        {
          :name           => "Amazon Credential",
          :userid         => "userid",
          :password       => ManageIQ::Password.encrypt("secret1"),
          :security_token => ManageIQ::Password.encrypt("secret2")
        }
      end
      let(:expected_values) do
        {
          :name               => "Amazon Credential",
          :userid             => "userid",
          :password           => "secret1",
          :security_token     => "secret2",
          :password_encrypted => ManageIQ::Password.try_encrypt("secret1"),
          :auth_key_encrypted => ManageIQ::Password.try_encrypt("secret2")
        }
      end
      let(:params_to_attrs) { [:auth_key] }
      let(:update_params) do
        {
          :name     => "Updated Credential",
          :password => "supersecret"
        }
      end
      let(:update_queue_params) do
        {
          :name     => "Updated Credential",
          :password => ManageIQ::Password.encrypt("supersecret")
        }
      end
    end
  end

  context "AzureCredential" do
    it_behaves_like 'an embedded_ansible credential' do
      let(:credential_class) { embedded_ansible::AzureCredential }

      let(:params) do
        {
          :name         => "Azure Credential",
          :userid       => "userid",
          :password     => "secret1",
          :secret       => "secret2",
          :client       => "client",
          :tenant       => "tenant",
          :subscription => "subscription"
        }
      end
      let(:queue_create_params) do
        {
          :name         => "Azure Credential",
          :userid       => "userid",
          :password     => ManageIQ::Password.encrypt("secret1"),
          :secret       => ManageIQ::Password.encrypt("secret2"),
          :client       => "client",
          :tenant       => "tenant",
          :subscription => "subscription"
        }
      end
      let(:params_to_attributes) do
        {
          :name     => "Azure Credential",
          :userid   => "userid",
          :password => "secret1",
          :auth_key => "secret2",
          :options  => {
            :client       => "client",
            :tenant       => "tenant",
            :subscription => "subscription"
          }
        }
      end
      let(:expected_values) do
        {
          :name               => "Azure Credential",
          :userid             => "userid",
          :password           => "secret1",
          :secret             => "secret2",
          :client             => "client",
          :tenant             => "tenant",
          :subscription       => "subscription",
          :password_encrypted => ManageIQ::Password.try_encrypt("secret1"),
          :auth_key_encrypted => ManageIQ::Password.try_encrypt("secret2"),
          :options            => {
            :client       => "client",
            :tenant       => "tenant",
            :subscription => "subscription"
          }
        }
      end
      let(:params_to_attrs) { [:auth_key, :client, :tenant, :subscription] }
      let(:update_params) do
        {
          :name     => "Updated Credential",
          :password => "supersecret"
        }
      end
      let(:update_queue_params) do
        {
          :name     => "Updated Credential",
          :password => ManageIQ::Password.encrypt("supersecret")
        }
      end

      it "#update_in_provider updating a single option" do
        ansible_cred = credential_class.raw_create_in_provider(manager, params)
        expect(Notification).to receive(:create!).never
        expect(ansible_cred.client).to eq("client")
        expect(ansible_cred.tenant).to eq("tenant")
        expect(ansible_cred.subscription).to eq("subscription")

        result = ansible_cred.update_in_provider(:name => "Updated Credential", :client => "foo")

        expect(result).to be_a(credential_class)
        expect(result.name).to eq("Updated Credential")
        expect(result.client).to eq("foo")
        expect(result.tenant).to eq("tenant")
        expect(result.subscription).to eq("subscription")
      end
    end
  end

  context "GoogleCredential" do
    it_behaves_like 'an embedded_ansible credential' do
      let(:credential_class) { embedded_ansible::GoogleCredential }

      let(:params) do
        {
          :name         => "Google Credential",
          :userid       => "userid",
          :ssh_key_data => "secret1",
          :project      => "project"
        }
      end
      let(:queue_create_params) do
        {
          :name         => "Google Credential",
          :userid       => "userid",
          :ssh_key_data => ManageIQ::Password.encrypt("secret1"),
          :project      => "project"
        }
      end
      let(:params_to_attributes) do
        {
          :name     => "Google Credential",
          :userid   => "userid",
          :auth_key => "secret1",
          :options  => {
            :project => "project"
          }
        }
      end
      let(:expected_values) do
        {
          :name               => "Google Credential",
          :userid             => "userid",
          :ssh_key_data       => "secret1",
          :project            => "project",
          :auth_key_encrypted => ManageIQ::Password.try_encrypt("secret1"),
          :options            => {
            :project => "project"
          }
        }
      end
      let(:params_to_attrs)     { [:auth_key, :project] }
      let(:update_params)       { {:name => "Updated Credential"} }
      let(:update_queue_params) { {:name => "Updated Credential"} }
    end
  end

  context "OpenstackCredential" do
    it_behaves_like 'an embedded_ansible credential' do
      let(:credential_class) { embedded_ansible::OpenstackCredential }

      let(:params) do
        {
          :name     => "OpenstackCredential Credential",
          :userid   => "userid",
          :password => "secret1",
          :host     => "host",
          :domain   => "domain",
          :project  => "project"
        }
      end
      let(:queue_create_params) do
        {
          :name     => "OpenstackCredential Credential",
          :userid   => "userid",
          :password => ManageIQ::Password.encrypt("secret1"),
          :host     => "host",
          :domain   => "domain",
          :project  => "project"
        }
      end
      let(:params_to_attributes) do
        {
          :name     => "OpenstackCredential Credential",
          :userid   => "userid",
          :password => "secret1",
          :options  => {
            :host    => "host",
            :domain  => "domain",
            :project => "project"
          }
        }
      end
      let(:expected_values) do
        {
          :name               => "OpenstackCredential Credential",
          :userid             => "userid",
          :password           => "secret1",
          :host               => "host",
          :domain             => "domain",
          :project            => "project",
          :password_encrypted => ManageIQ::Password.try_encrypt("secret1"),
          :options            => {
            :host    => "host",
            :domain  => "domain",
            :project => "project"
          }
        }
      end
      let(:params_to_attrs) { [:host, :domain, :project] }
      let(:update_params) do
        {
          :name     => "Updated Credential",
          :password => "supersecret"
        }
      end
      let(:update_queue_params) do
        {
          :name     => "Updated Credential",
          :password => ManageIQ::Password.encrypt("supersecret")
        }
      end
    end
  end

  context "RhvCredential" do
    it_behaves_like 'an embedded_ansible credential' do
      let(:credential_class) { embedded_ansible::RhvCredential }

      let(:params) do
        {
          :name     => "Rhv Credential",
          :userid   => "userid",
          :password => "secret1",
          :host     => "host"
        }
      end
      let(:queue_create_params) do
        {
          :name     => "Rhv Credential",
          :userid   => "userid",
          :password => ManageIQ::Password.encrypt("secret1"),
          :host     => "host"
        }
      end
      let(:params_to_attributes) do
        {
          :name     => "Rhv Credential",
          :userid   => "userid",
          :password => "secret1",
          :options  => {
            :host => "host"
          }
        }
      end
      let(:expected_values) do
        {
          :name               => "Rhv Credential",
          :userid             => "userid",
          :password           => "secret1",
          :host               => "host",
          :password_encrypted => ManageIQ::Password.try_encrypt("secret1"),
          :options            => {
            :host => "host"
          }
        }
      end
      let(:params_to_attrs) { [:host] }
      let(:update_params) do
        {
          :name     => "Updated Credential",
          :password => "supersecret"
        }
      end
      let(:update_queue_params) do
        {
          :name     => "Updated Credential",
          :password => ManageIQ::Password.encrypt("supersecret")
        }
      end
    end
  end

  context "VmwareCredential" do
    it_behaves_like 'an embedded_ansible credential' do
      let(:credential_class) { embedded_ansible::VmwareCredential }

      let(:params) do
        {
          :name     => "VMware Credential",
          :userid   => "userid",
          :password => "secret1",
          :host     => "host"
        }
      end
      let(:queue_create_params) do
        {
          :name     => "VMware Credential",
          :userid   => "userid",
          :password => ManageIQ::Password.encrypt("secret1"),
          :host     => "host"
        }
      end
      let(:params_to_attributes) do
        {
          :name     => "VMware Credential",
          :userid   => "userid",
          :password => "secret1",
          :options  => {
            :host => "host"
          }
        }
      end
      let(:expected_values) do
        {
          :name               => "VMware Credential",
          :userid             => "userid",
          :password           => "secret1",
          :host               => "host",
          :password_encrypted => ManageIQ::Password.try_encrypt("secret1"),
          :options            => {
            :host => "host"
          }
        }
      end
      let(:params_to_attrs) { [:host] }
      let(:update_params) do
        {
          :name     => "Updated Credential",
          :password => "supersecret"
        }
      end
      let(:update_queue_params) do
        {
          :name     => "Updated Credential",
          :password => ManageIQ::Password.encrypt("supersecret")
        }
      end
    end
  end
end
