require "linux_admin"
require "awesome_spawn"

describe EmbeddedAnsible do
  before do
    ENV["APPLIANCE_ANSIBLE_DIRECTORY"] = nil
  end

  context ".available?" do
    it "returns true when installed in the default location" do
      allow(Dir).to receive(:exist?).with("/opt/ansible-installer").and_return(true)

      expect(described_class.available?).to be_truthy
    end

    it "returns true when installed in the custom location in env var" do
      ENV["APPLIANCE_ANSIBLE_DIRECTORY"] = "/tmp"
      allow(Dir).to receive(:exist?).with("/tmp").and_return(true)
      allow(Dir).to receive(:exist?).with("/opt/ansible-installer").and_return(false)

      expect(described_class.available?).to be_truthy
    end

    it "returns false when not installed" do
      allow(Dir).to receive(:exist?).with("/opt/ansible-installer").and_return(false)

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
  end

  context "with an miq_databases row" do
    let(:miq_database) { MiqDatabase.first }
    let(:extra_vars) do
      {
        :minimum_var_space => 0,
        :nginx_http_port   => described_class::NGINX_HTTP_PORT,
        :nginx_https_port  => described_class::NGINX_HTTPS_PORT
      }.to_json
    end

    before do
      FactoryGirl.create(:miq_region, :region => ApplicationRecord.my_region_number)
      MiqDatabase.seed
      EvmSpecHelper.create_guid_miq_server_zone
    end

    context "with a key file" do
      let(:key_file) { Tempfile.new("SECRET_KEY") }

      before do
        stub_const("EmbeddedAnsible::SECRET_KEY_FILE", key_file.path)
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

    describe ".configure" do
      before do
        expect(described_class).to receive(:configure_secret_key)
        expect(described_class).to receive(:stop)
      end

      it "generates new passwords with no passwords set" do
        expect(described_class).to receive(:generate_database_authentication).and_return(double(:userid => "awx", :password => "databasepassword"))
        expect(AwesomeSpawn).to receive(:run!) do |script_path, options|
          params                  = options[:params]
          inventory_file_contents = File.read(params[:i])

          expect(script_path).to eq("/opt/ansible-installer/setup.sh")
          expect(params[:e]).to eq(extra_vars)
          expect(params[:k]).to eq("packages,migrations,firewall,supervisor")

          new_admin_auth  = miq_database.ansible_admin_authentication
          new_rabbit_auth = miq_database.ansible_rabbitmq_authentication
          expect(new_admin_auth.userid).to eq("admin")
          expect(inventory_file_contents).to include("admin_password='#{new_admin_auth.password}'")
          expect(inventory_file_contents).to include("rabbitmq_username='#{new_rabbit_auth.userid}'")
          expect(inventory_file_contents).to include("rabbitmq_password='#{new_rabbit_auth.password}'")
          expect(inventory_file_contents).to include("pg_username='awx'")
          expect(inventory_file_contents).to include("pg_password='databasepassword'")
        end

        described_class.configure
      end

      it "uses the existing passwords when they are set in the database" do
        miq_database.set_ansible_admin_authentication("adminpassword")
        miq_database.set_ansible_rabbitmq_authentication("rabbitpassword", "rabbituser")
        miq_database.set_ansible_database_authentication("databasepassword", "databaseuser")

        expect(AwesomeSpawn).to receive(:run!) do |script_path, options|
          params                  = options[:params]
          inventory_file_contents = File.read(params[:i])

          expect(script_path).to eq("/opt/ansible-installer/setup.sh")
          expect(params[:e]).to eq(extra_vars)
          expect(params[:k]).to eq("packages,migrations,firewall,supervisor")

          expect(inventory_file_contents).to include("admin_password='adminpassword'")
          expect(inventory_file_contents).to include("rabbitmq_username='rabbituser'")
          expect(inventory_file_contents).to include("rabbitmq_password='rabbitpassword'")
          expect(inventory_file_contents).to include("pg_username='databaseuser'")
          expect(inventory_file_contents).to include("pg_password='databasepassword'")
        end

        described_class.configure
      end
    end

    describe ".start" do
      it "runs the setup script with the correct args" do
        miq_database.set_ansible_admin_authentication("adminpassword")
        miq_database.set_ansible_rabbitmq_authentication("rabbitpassword", "rabbituser")
        miq_database.set_ansible_database_authentication("databasepassword", "databaseuser")

        expect(AwesomeSpawn).to receive(:run!) do |script_path, options|
          params                  = options[:params]
          inventory_file_contents = File.read(params[:i])

          expect(script_path).to eq("/opt/ansible-installer/setup.sh")
          expect(params[:e]).to eq(extra_vars)
          expect(params[:k]).to eq("packages,migrations,firewall")

          expect(inventory_file_contents).to include("admin_password='adminpassword'")
          expect(inventory_file_contents).to include("rabbitmq_username='rabbituser'")
          expect(inventory_file_contents).to include("rabbitmq_password='rabbitpassword'")
          expect(inventory_file_contents).to include("pg_username='databaseuser'")
          expect(inventory_file_contents).to include("pg_password='databasepassword'")
        end

        described_class.start
      end
    end
  end
end
