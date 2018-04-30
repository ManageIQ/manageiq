require "linux_admin"
require "awesome_spawn"

describe EmbeddedAnsible do
  context ".available?" do
    context "in an appliance" do
      before do
        allow(MiqEnvironment::Command).to receive(:is_appliance?).and_return(true)
      end

      it "returns true when installed in the default location" do
        installed_rpms = {
          "ansible-tower-server" => "1.0.1",
          "ansible-tower-setup"  => "1.2.3",
          "vim"                  => "13.5.1"
        }
        expect(LinuxAdmin::Rpm).to receive(:list_installed).and_return(installed_rpms)

        expect(described_class.available?).to be_truthy
      end

      it "returns false when not installed" do
        expect(LinuxAdmin::Rpm).to receive(:list_installed).and_return("vim" => "13.5.1")

        expect(described_class.available?).to be_falsey
      end
    end

    it "returns false outside of an appliance" do
      allow(MiqEnvironment::Command).to receive(:is_appliance?).and_return(false)
      expect(described_class.available?).to be_falsey
    end
  end

  context "with services" do
    let(:nginx_service)       { double("nginx service") }
    let(:supervisord_service) { double("supervisord service") }
    let(:rabbitmq_service)    { double("rabbitmq service") }

    before do
      expect(AwesomeSpawn).to receive(:run!)
        .with("source /etc/sysconfig/ansible-tower; echo $TOWER_SERVICES")
        .and_return(double(:output => "nginx supervisord rabbitmq"))
      allow(LinuxAdmin::Service).to receive(:new).with("nginx").and_return(nginx_service)
      allow(LinuxAdmin::Service).to receive(:new).with("supervisord").and_return(supervisord_service)
      allow(LinuxAdmin::Service).to receive(:new).with("rabbitmq").and_return(rabbitmq_service)
    end

    describe ".running?" do
      it "returns true when all services are running" do
        expect(nginx_service).to receive(:running?).and_return(true)
        expect(supervisord_service).to receive(:running?).and_return(true)
        expect(rabbitmq_service).to receive(:running?).and_return(true)

        expect(described_class.running?).to be true
      end

      it "returns false when a service is not running" do
        expect(nginx_service).to receive(:running?).and_return(true)
        expect(supervisord_service).to receive(:running?).and_return(false)

        expect(described_class.running?).to be false
      end
    end

    describe ".stop" do
      it "stops all the services" do
        expect(nginx_service).to receive(:stop).and_return(nginx_service)
        expect(supervisord_service).to receive(:stop).and_return(supervisord_service)
        expect(rabbitmq_service).to receive(:stop).and_return(rabbitmq_service)

        described_class.stop
      end
    end

    describe ".disable" do
      it "stops and disables all the services" do
        expect(nginx_service).to receive(:stop).and_return(nginx_service)
        expect(supervisord_service).to receive(:stop).and_return(supervisord_service)
        expect(rabbitmq_service).to receive(:stop).and_return(rabbitmq_service)

        expect(nginx_service).to receive(:disable).and_return(nginx_service)
        expect(supervisord_service).to receive(:disable).and_return(supervisord_service)
        expect(rabbitmq_service).to receive(:disable).and_return(rabbitmq_service)

        described_class.disable
      end
    end

    describe ".start when configured and not upgrading" do
      let(:version_file) { Tempfile.new("tower_version") }

      before do
        version_file.write("3.1.3\n")
        version_file.close
        stub_const("EmbeddedAnsible::TOWER_VERSION_FILE", version_file.path)
        expect(LinuxAdmin::Rpm).to receive(:info).with("ansible-tower-server").and_return("version" => "3.1.3")

        stub_const("EmbeddedAnsible::WAIT_FOR_ANSIBLE_SLEEP", 0)

        expect(EmbeddedAnsible).to receive(:configured?).and_return true

        expect(nginx_service).to receive(:start).and_return(nginx_service)
        expect(supervisord_service).to receive(:start).and_return(supervisord_service)
        expect(rabbitmq_service).to receive(:start).and_return(rabbitmq_service)

        expect(nginx_service).to receive(:enable).and_return(nginx_service)
        expect(supervisord_service).to receive(:enable).and_return(supervisord_service)
        expect(rabbitmq_service).to receive(:enable).and_return(rabbitmq_service)
        expect(described_class).to receive(:update_proxy_settings)
      end

      it "waits for Ansible to respond" do
        expect(described_class).to receive(:alive?).exactly(3).times.and_return(false, false, true)

        described_class.start
      end

      it "raises if Ansible doesn't respond" do
        expect(described_class).to receive(:alive?).exactly(5).times.and_return(false)

        expect { described_class.start }.to raise_error(RuntimeError)
      end
    end
  end

  context "with an miq_databases row" do
    let(:miq_database) { MiqDatabase.first }
    let(:extra_vars) do
      {
        :awx_install_memcached_bind => ::Settings.session.memcache_server,
        :minimum_var_space          => 0,
        :http_port                  => described_class::HTTP_PORT,
        :https_port                 => described_class::HTTPS_PORT,
        :tower_package_name         => "ansible-tower-server"
      }.to_json
    end

    before do
      FactoryGirl.create(:miq_region, :region => ApplicationRecord.my_region_number)
      MiqDatabase.seed
      EvmSpecHelper.create_guid_miq_server_zone
    end

    describe ".alive?" do
      it "returns false if the service is not configured" do
        expect(described_class).to receive(:configured?).and_return false
        expect(described_class.alive?).to be false
      end

      it "returns false if the service is not running" do
        expect(described_class).to receive(:configured?).and_return true
        expect(described_class).to receive(:running?).and_return false
        expect(described_class.alive?).to be false
      end

      context "when a connection is attempted" do
        let(:api_conn) { double("AnsibleAPIConnection") }
        let(:api) { double("AnsibleAPIResource") }

        before do
          expect(described_class).to receive(:configured?).and_return true
          expect(described_class).to receive(:running?).and_return true

          miq_database.set_ansible_admin_authentication(:password => "adminpassword")

          expect(AnsibleTowerClient::Connection).to receive(:new).with(
            :base_url => "http://localhost:54321/api/v1",
            :username => "admin",
            :password => "adminpassword"
          ).and_return(api_conn)
          expect(api_conn).to receive(:api).and_return(api)
        end

        it "returns false when a AnsibleTowerClient::ConnectionError is raised" do
          error = AnsibleTowerClient::ConnectionError.new("error")
          expect(api).to receive(:verify_credentials).and_raise(error)
          expect(described_class.alive?).to be false
        end

        it "returns false when a AnsibleTowerClient::SSLError is raised" do
          error = AnsibleTowerClient::SSLError.new("error")
          expect(api).to receive(:verify_credentials).and_raise(error)
          expect(described_class.alive?).to be false
        end

        it "returns false when an AnsibleTowerClient::ConnectionError is raised" do
          expect(api).to receive(:verify_credentials).and_raise(AnsibleTowerClient::ConnectionError)
          expect(described_class.alive?).to be false
        end

        it "returns false when an AnsibleTowerClient::ClientError is raised" do
          expect(api).to receive(:verify_credentials).and_raise(AnsibleTowerClient::ClientError)
          expect(described_class.alive?).to be false
        end

        it "raises when other errors are raised" do
          expect(api).to receive(:verify_credentials).and_raise(RuntimeError)
          expect { described_class.alive? }.to raise_error(RuntimeError)
        end

        it "returns true when no error is raised" do
          expect(api).to receive(:verify_credentials)
          expect(described_class.alive?).to be true
        end
      end
    end

    context "with a key file" do
      let(:key_file)      { Tempfile.new("SECRET_KEY") }
      let(:complete_file) { Tempfile.new("embedded_ansible_setup_complete") }

      before do
        stub_const("EmbeddedAnsible::SECRET_KEY_FILE", key_file.path)
        allow(described_class).to receive(:setup_complete_file).and_return(complete_file.path)
      end

      after do
        key_file.unlink
      end

      describe ".configured?" do
        it "returns true when the key in the file is the same as the one in the database" do
          key = "verysecret"
          key_file.write(key)
          key_file.close
          miq_database.ansible_secret_key = key

          expect(described_class.configured?).to be true
        end

        it "returns false when the key is configured but the complete file is missing" do
          key = "verysecret"
          key_file.write(key)
          key_file.close
          miq_database.ansible_secret_key = key

          complete_file.unlink

          expect(described_class.configured?).to be false
        end

        it "returns false when there is no key in the database" do
          key_file.write("asdf")
          key_file.close

          expect(described_class.configured?).to be false
        end

        it "returns false when the key in the file doesn't match the one in the database" do
          key_file.write("qwerty")
          key_file.close
          miq_database.ansible_secret_key = "password"

          expect(described_class.configured?).to be false
        end

        it "returns false when the file doesn't exist and there is a value in the database" do
          key_file.unlink
          miq_database.ansible_secret_key = "password"
          expect(described_class.configured?).to be false
        end
      end

      describe ".configure_secret_key (private)" do
        it "sets a new key when there is no key in the database" do
          expect(miq_database.ansible_secret_key).to be_nil
          described_class.send(:configure_secret_key)
          miq_database.reload
          expect(miq_database.ansible_secret_key).to match(/\h+/)
          expect(miq_database.ansible_secret_key).to eq(File.read(key_file.path))
        end

        it "writes the key when a key is in the database" do
          miq_database.ansible_secret_key = "supasecret"
          expect(miq_database).not_to receive(:ansible_secret_key=)
          described_class.send(:configure_secret_key)
          expect(File.read(key_file.path)).to eq("supasecret")
        end
      end
    end

    describe ".start when configured and upgrading" do
      let(:version_file) { Tempfile.new("tower_version") }

      before do
        version_file.write("3.1.2\n")
        version_file.close
        stub_const("EmbeddedAnsible::TOWER_VERSION_FILE", version_file.path)
        expect(LinuxAdmin::Rpm).to receive(:info).with("ansible-tower-server").and_return("version" => "3.1.3")

        expect(described_class).to receive(:configured?).and_return(true)
        expect(described_class).to receive(:configure_secret_key)
      end

      it "runs the setup playbook" do
        expect(described_class).to receive(:alive?).and_return(true)
        miq_database.set_ansible_admin_authentication(:password => "adminpassword")
        miq_database.set_ansible_rabbitmq_authentication(:userid => "rabbituser", :password => "rabbitpassword")
        miq_database.set_ansible_database_authentication(:userid => "databaseuser", :password => "databasepassword")

        expect(AwesomeSpawn).to receive(:run!).with("ansible-tower-setup", anything)

        described_class.start
      end
    end

    describe ".start when not configured" do
      before do
        expect(described_class).to receive(:configured?).and_return(false)
        expect(described_class).to receive(:configure_secret_key)
      end

      it "generates new passwords with no passwords set" do
        expect(described_class).to receive(:alive?).and_return(true)
        expect(described_class).to receive(:generate_database_authentication).and_return(double(:userid => "awx", :password => "databasepassword"))
        expect(AwesomeSpawn).to receive(:run!) do |script_path, options|
          params                  = options[:params]
          inventory_file_contents = File.read(params[:inventory=])

          expect(script_path).to eq("ansible-tower-setup")
          expect(params["--"]).to be_nil
          expect(params[:extra_vars=]).to eq(extra_vars)
          expect(params[:skip_tags=]).to eq("packages,migrations,firewall")

          new_admin_auth  = miq_database.ansible_admin_authentication
          new_rabbit_auth = miq_database.ansible_rabbitmq_authentication
          expect(new_admin_auth.userid).to eq("admin")
          expect(inventory_file_contents).to include("admin_password='#{new_admin_auth.password}'")
          expect(inventory_file_contents).to include("rabbitmq_username='#{new_rabbit_auth.userid}'")
          expect(inventory_file_contents).to include("rabbitmq_password='#{new_rabbit_auth.password}'")
          expect(inventory_file_contents).to include("pg_username='awx'")
          expect(inventory_file_contents).to include("pg_password='databasepassword'")
        end

        described_class.start
      end

      it "uses the existing passwords when they are set in the database" do
        expect(described_class).to receive(:alive?).and_return(true)
        miq_database.set_ansible_admin_authentication(:password => "adminpassword")
        miq_database.set_ansible_rabbitmq_authentication(:userid => "rabbituser", :password => "rabbitpassword")
        miq_database.set_ansible_database_authentication(:userid => "databaseuser", :password => "databasepassword")

        expect(AwesomeSpawn).to receive(:run!) do |script_path, options|
          params                  = options[:params]
          inventory_file_contents = File.read(params[:inventory=])

          expect(script_path).to eq("ansible-tower-setup")
          expect(params["--"]).to be_nil
          expect(params[:extra_vars=]).to eq(extra_vars)
          expect(params[:skip_tags=]).to eq("packages,migrations,firewall")

          expect(inventory_file_contents).to include("admin_password='adminpassword'")
          expect(inventory_file_contents).to include("rabbitmq_username='rabbituser'")
          expect(inventory_file_contents).to include("rabbitmq_password='rabbitpassword'")
          expect(inventory_file_contents).to include("pg_username='databaseuser'")
          expect(inventory_file_contents).to include("pg_password='databasepassword'")
        end

        described_class.start
      end

      it "removes the secret key from the database when setup fails" do
        miq_database.ansible_secret_key = "supersecretkey"
        expect(described_class).to receive(:generate_database_authentication).and_return(double(:userid => "awx", :password => "databasepassword"))

        expect(AwesomeSpawn).to receive(:run!).and_raise(AwesomeSpawn::CommandResultError.new("error", 1))
        expect { described_class.start }.to raise_error(AwesomeSpawn::CommandResultError)
        expect(miq_database.reload.ansible_secret_key).not_to be_present
      end
    end

    describe ".generate_database_authentication (private)" do
      let(:password)        { "secretpassword" }
      let(:quoted_password) { ActiveRecord::Base.connection.quote(password) }
      let(:connection)      { double(:quote => quoted_password) }

      before do
        allow(connection).to receive(:quote_column_name) do |name|
          ActiveRecord::Base.connection.quote_column_name(name)
        end
      end

      it "creates the database" do
        allow(described_class).to receive(:database_connection).and_return(connection)
        expect(described_class).to receive(:generate_password).and_return(password)
        expect(connection).to receive(:select_value).with("CREATE ROLE \"awx\" WITH LOGIN PASSWORD #{quoted_password}")
        expect(connection).to receive(:select_value).with("CREATE DATABASE awx OWNER \"awx\" ENCODING 'utf8'")

        auth = described_class.send(:generate_database_authentication)
        expect(auth.userid).to eq("awx")
        expect(auth.password).to eq(password)
      end
    end

    describe ".update_proxy_settings (private)" do
      let(:file_content) do
        <<-EOF
# Arbitrary line 1

# Arbitrary line 2
AWX_TASK_ENV['HTTP_PROXY'] = 'somehost'
AWX_TASK_ENV['HTTPS_PROXY'] = 'somehost'
AWX_TASK_ENV['NO_PROXY'] = 'somehost'
EOF
      end
      let(:proxy_uri) { "http://user:password@localhost:3333" }
      let(:settings_file) { Tempfile.new("settings.py") }
      before do
        settings_file.write(file_content)
        settings_file.close
        stub_const("EmbeddedAnsible::SETTINGS_FILE", settings_file.path)
        expect(VMDB::Util).to receive(:http_proxy_uri).and_return(proxy_uri)
      end

      it "add current proxy info" do
        described_class.send(:update_proxy_settings)
        new_contents = File.read(settings_file.path)
        expect(new_contents).to include("AWX_TASK_ENV['HTTP_PROXY'] = '#{proxy_uri}'\n")
        expect(new_contents).to include("AWX_TASK_ENV['HTTPS_PROXY'] = '#{proxy_uri}'\n")
        expect(new_contents).to include("AWX_TASK_ENV['NO_PROXY'] = '127.0.0.1'\n")
        expect(new_contents).not_to include("'somehost'")
      end
    end
  end
end
