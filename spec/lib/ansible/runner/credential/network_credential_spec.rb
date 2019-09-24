require 'ansible/runner'
require 'ansible/runner/credential'

RSpec.describe Ansible::Runner::NetworkCredential do
  it ".auth_type is the correct Authentication sub-class" do
    expect(described_class.auth_type).to eq("ManageIQ::Providers::EmbeddedAnsible::AutomationManager::NetworkCredential")
  end

  context "with a credential object" do
    around do |example|
      Dir.mktmpdir("ansible-runner-credential-test") do |dir|
        @base_dir = dir
        example.run
      end
    end

    let(:auth)     { FactoryBot.create(:embedded_ansible_network_credential, auth_attributes) }
    let(:cred)     { described_class.new(auth.id, @base_dir) }
    let(:key_file) { File.join(@base_dir, "env", "network_ssh_key") }
    let(:auth_attributes) do
      {
        :userid   => "manageiq-network",
        :password => "network_secret"
      }
    end

    describe "#command_line" do
      it "returns an empty hash" do
        expect(cred.command_line).to eq({})
      end
    end

    # Modeled off of awx codebase:
    #
    #   https://github.com/ansible/awx/blob/1242ee2b/awx/main/tasks.py#L1432-L1443
    #
    describe "#env_vars" do
      it "sets ANSIBLE_NET_USERNAME, ANSIBLE_NET_PASSWORD, and ANSIBLE_NET_AUTHORIZE" do
        expected = {
          "ANSIBLE_NET_USERNAME"  => "manageiq-network",
          "ANSIBLE_NET_PASSWORD"  => "network_secret",
          "ANSIBLE_NET_AUTHORIZE" => "0",
        }
        expect(cred.env_vars).to eq(expected)
      end

      context "with an auth_key" do
        let(:auth_attributes) do
          {
            :userid   => "",
            :password => "",
            :auth_key => "key_data"
          }
        end

        it "sets ANSIBLE_NET_SSH_KEYFILE to the network_ssh_key_file location" do
          expected = {
            "ANSIBLE_NET_USERNAME"    => "",
            "ANSIBLE_NET_PASSWORD"    => "",
            "ANSIBLE_NET_AUTHORIZE"   => "0",
            "ANSIBLE_NET_SSH_KEYFILE" => key_file
          }
          expect(cred.env_vars).to eq(expected)
        end
      end

      context "with authorize set" do
        let(:auth_attributes) do
          {
            :userid   => "user",
            :password => "pass",
            :options  => { :authorize => true }
          }
        end

        it "sets ANSIBLE_NET_AUTHORIZE to '1'" do
          expected = {
            "ANSIBLE_NET_USERNAME"  => "user",
            "ANSIBLE_NET_PASSWORD"  => "pass",
            "ANSIBLE_NET_AUTHORIZE" => "1",
            "ANSIBLE_NET_AUTH_PASS" => ""
          }
          expect(cred.env_vars).to eq(expected)
        end

        it "defines ANSIBLE_NET_AUTH_PASS if it is present" do
          auth.update!(:become_password => "auth_pass")
          expected = {
            "ANSIBLE_NET_USERNAME"  => "user",
            "ANSIBLE_NET_PASSWORD"  => "pass",
            "ANSIBLE_NET_AUTHORIZE" => "1",
            "ANSIBLE_NET_AUTH_PASS" => "auth_pass"
          }
          expect(cred.env_vars).to eq(expected)
        end
      end
    end

    describe "#extra_vars" do
      it "returns an empty hash" do
        expect(cred.extra_vars).to eq({})
      end
    end

    describe "#write_config_files" do
      let(:password_file) { File.join(@base_dir, "env", "passwords") }

      def password_hash
        YAML.load_file(password_file)
      end

      context "with an auth_key" do
        let(:auth_attributes) { { :auth_key => "key_data" } }

        it "writes the network_ssh_key_file" do
          cred.write_config_files
          expect(File.read(key_file)).to eq("key_data")
          expect(File.stat(key_file).mode).to eq(0o100400)
        end
      end

      context "without an auth_key" do
        it "writes the network_ssh_key_file" do
          cred.write_config_files
          expect(File.exist?(key_file)).to be_falsey
        end
      end

      context "with authorize set" do
        let(:ssh_unlock_key) { "^Enter passphrase for [a-zA-Z0-9\-\/]+\/ssh_key_data:" }
        let(:auth_attributes) do
          {
            :userid            => "user",
            :password          => "pass",
            :auth_key_password => "key_pass",
            :options           => { :authorize => true }
          }
        end

        it "writes the password file" do
          cred.write_config_files

          expect(password_hash).to eq(ssh_unlock_key => "key_pass")
        end

        it "defaults auth_key_password to ''" do
          auth.update!(:auth_key_password => nil)
          cred.write_config_files

          expect(password_hash).to eq(ssh_unlock_key => "")
        end

        context "and an existing password file" do
          def existing_env_password_file(data)
            cred # initialize the dir
            File.write(password_file, data.to_yaml)
          end

          it "without the existing ssh unlock key adds the password to the file" do
            existing_data = {
              "^SSH [pP]assword:"    => "hunter2",
              "^BECOME [pP]assword:" => "hunter3"
            }
            expected_data = existing_data.merge(ssh_unlock_key => "key_pass")
            existing_env_password_file(existing_data)
            cred.write_config_files

            expect(password_hash).to eq(expected_data)
          end

          it "with the existing data including the ssh unlock does nothing" do
            existing_data = {
              "^SSH [pP]assword:"    => "hunter2",
              "^BECOME [pP]assword:" => "hunter3",
              ssh_unlock_key         => "hunter4...really?"
            }
            existing_env_password_file(existing_data)
            cred.write_config_files

            expect(password_hash).to eq(existing_data)
          end
        end
      end
    end
  end
end
