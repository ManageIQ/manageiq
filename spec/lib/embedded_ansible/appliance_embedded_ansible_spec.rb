require 'linux_admin'
require 'docker'
require_dependency 'embedded_ansible'

describe ApplianceEmbeddedAnsible do
  before do
    allow(MiqEnvironment::Command).to receive(:is_appliance?).and_return(true)
    allow(ContainerOrchestrator).to receive(:available?).and_return(false)
    allow(Docker).to receive(:validate_version!).and_raise(RuntimeError)

    installed_rpms = {
      "ansible-tower-server" => "1.0.1",
      "ansible-tower-setup"  => "1.2.3",
      "vim"                  => "13.5.1"
    }
    allow(LinuxAdmin::Rpm).to receive(:list_installed).and_return(installed_rpms)
  end

  describe "subject" do
    it "is an instance of ApplianceEmbeddedAnsible" do
      expect(subject).to be_an_instance_of(described_class)
    end
  end

  describe ".available?" do
    it "returns true with the tower rpms installed" do
      expect(described_class.available?).to be true
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

    describe "#running?" do
      it "returns true when all services are running" do
        expect(nginx_service).to receive(:running?).and_return(true)
        expect(supervisord_service).to receive(:running?).and_return(true)
        expect(rabbitmq_service).to receive(:running?).and_return(true)

        expect(subject.running?).to be true
      end

      it "returns false when a service is not running" do
        expect(nginx_service).to receive(:running?).and_return(true)
        expect(supervisord_service).to receive(:running?).and_return(false)

        expect(subject.running?).to be false
      end
    end

    describe ".stop" do
      it "stops all the services" do
        expect(nginx_service).to receive(:stop).and_return(nginx_service)
        expect(supervisord_service).to receive(:stop).and_return(supervisord_service)
        expect(rabbitmq_service).to receive(:stop).and_return(rabbitmq_service)

        subject.stop
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

        subject.disable
      end
    end

    describe "#start when configured and not upgrading" do
      let(:version_file) { Tempfile.new("tower_version") }

      before do
        version_file.write("3.1.3\n")
        version_file.close
        stub_const("ApplianceEmbeddedAnsible::TOWER_VERSION_FILE", version_file.path)
        expect(LinuxAdmin::Rpm).to receive(:info).with("ansible-tower-server").and_return("version" => "3.1.3")

        stub_const("EmbeddedAnsible::WAIT_FOR_ANSIBLE_SLEEP", 0)

        expect(subject).to receive(:configured?).and_return true

        expect(nginx_service).to receive(:start).and_return(nginx_service)
        expect(supervisord_service).to receive(:start).and_return(supervisord_service)
        expect(rabbitmq_service).to receive(:start).and_return(rabbitmq_service)

        expect(nginx_service).to receive(:enable).and_return(nginx_service)
        expect(supervisord_service).to receive(:enable).and_return(supervisord_service)
        expect(rabbitmq_service).to receive(:enable).and_return(rabbitmq_service)
        expect(subject).to receive(:update_proxy_settings)
      end

      it "waits for Ansible to respond" do
        expect(subject).to receive(:alive?).exactly(3).times.and_return(false, false, true)

        subject.start
      end

      it "raises if Ansible doesn't respond" do
        expect(subject).to receive(:alive?).exactly(5).times.and_return(false)

        expect { subject.start }.to raise_error(RuntimeError)
      end
    end
  end

  context "with an miq_databases row" do
    let(:miq_database) { MiqDatabase.first }
    let(:extra_vars) do
      {
        :awx_install_memcached_bind => MiqMemcached.server_address,
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

    context "with a key file" do
      let(:key_file)      { Tempfile.new("SECRET_KEY") }
      let(:complete_file) { Tempfile.new("embedded_ansible_setup_complete") }

      before do
        stub_const("ApplianceEmbeddedAnsible::SECRET_KEY_FILE", key_file.path)
        allow(subject).to receive(:setup_complete_file).and_return(complete_file.path)
      end

      after do
        key_file.unlink
      end

      describe "#configured?" do
        it "returns true when the key in the file is the same as the one in the database" do
          key = "verysecret"
          key_file.write(key)
          key_file.close
          miq_database.ansible_secret_key = key

          expect(subject.configured?).to be true
        end

        it "returns false when the key is configured but the complete file is missing" do
          key = "verysecret"
          key_file.write(key)
          key_file.close
          miq_database.ansible_secret_key = key

          complete_file.unlink

          expect(subject.configured?).to be false
        end

        it "returns false when there is no key in the database" do
          key_file.write("asdf")
          key_file.close

          expect(subject.configured?).to be false
        end

        it "returns false when the key in the file doesn't match the one in the database" do
          key_file.write("qwerty")
          key_file.close
          miq_database.ansible_secret_key = "password"

          expect(subject.configured?).to be false
        end

        it "returns false when the file doesn't exist and there is a value in the database" do
          key_file.unlink
          miq_database.ansible_secret_key = "password"
          expect(subject.configured?).to be false
        end
      end

      describe "#configure_secret_key (private)" do
        it "sets a new key when there is no key in the database" do
          expect(miq_database.ansible_secret_key).to be_nil
          subject.send(:configure_secret_key)
          miq_database.reload
          expect(miq_database.ansible_secret_key).to match(/\h+/)
          expect(miq_database.ansible_secret_key).to eq(File.read(key_file.path))
        end

        it "writes the key when a key is in the database" do
          miq_database.ansible_secret_key = "supasecret"
          expect(miq_database).not_to receive(:ansible_secret_key=)
          subject.send(:configure_secret_key)
          expect(File.read(key_file.path)).to eq("supasecret")
        end
      end
    end

    describe "#start when configured and upgrading" do
      let(:version_file) { Tempfile.new("tower_version") }

      before do
        version_file.write("3.1.2\n")
        version_file.close
        stub_const("ApplianceEmbeddedAnsible::TOWER_VERSION_FILE", version_file.path)
        expect(LinuxAdmin::Rpm).to receive(:info).with("ansible-tower-server").and_return("version" => "3.1.3")

        expect(subject).to receive(:configured?).and_return(true)
        expect(subject).to receive(:configure_secret_key)
      end

      it "runs the setup playbook" do
        expect(subject).to receive(:alive?).and_return(true)
        miq_database.set_ansible_admin_authentication(:password => "adminpassword")
        miq_database.set_ansible_rabbitmq_authentication(:userid => "rabbituser", :password => "rabbitpassword")
        miq_database.set_ansible_database_authentication(:userid => "databaseuser", :password => "databasepassword")

        expect(AwesomeSpawn).to receive(:run!).with("ansible-tower-setup", anything)

        subject.start
      end
    end

    describe "#start with the force setup run marker file" do
      it "runs the setup playbook" do
        file = Rails.root.join("tmp", "embedded_ansible_force_setup_run")
        FileUtils.touch(file)

        expect(subject).to receive(:configure_secret_key)
        expect(subject).to receive(:alive?).and_return(true)
        miq_database.set_ansible_admin_authentication(:password => "adminpassword")
        miq_database.set_ansible_rabbitmq_authentication(:userid => "rabbituser", :password => "rabbitpassword")
        miq_database.set_ansible_database_authentication(:userid => "databaseuser", :password => "databasepassword")

        expect(AwesomeSpawn).to receive(:run!).with("ansible-tower-setup", anything)

        subject.start
        FileUtils.rm_f(file)
      end
    end

    describe "#start when not configured" do
      before do
        expect(subject).to receive(:configured?).and_return(false)
        expect(subject).to receive(:configure_secret_key)
      end

      it "generates new passwords with no passwords set" do
        expect(subject).to receive(:alive?).and_return(true)
        expect(subject).to receive(:find_or_create_database_authentication).and_return(double(:userid => "awx", :password => "databasepassword"))
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

        subject.start
      end

      it "uses the existing passwords when they are set in the database" do
        expect(subject).to receive(:alive?).and_return(true)
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

        subject.start
      end

      it "removes the secret key from the database when setup fails" do
        miq_database.ansible_secret_key = "supersecretkey"
        expect(subject).to receive(:find_or_create_database_authentication).and_return(double(:userid => "awx", :password => "databasepassword"))

        expect(AwesomeSpawn).to receive(:run!).and_raise(AwesomeSpawn::CommandResultError.new("error", 1))
        expect { subject.start }.to raise_error(AwesomeSpawn::CommandResultError)
        expect(miq_database.reload.ansible_secret_key).not_to be_present
      end
    end
  end

  describe "#create_local_playbook_repo" do
    let!(:tmp_dir) { Pathname.new(Dir.mktmpdir("consolidated_ansible_playbooks")) }

    before do
      allow(subject).to receive(:playbook_repo_path).and_return(tmp_dir)
    end

    it "creates a git project containing the plugin playbooks" do
      expect(FileUtils).to receive(:chown_R).with("awx", "awx", tmp_dir)
      subject.create_local_playbook_repo
      expect(Dir.exist?(tmp_dir.join(".git"))).to be_truthy
    end
  end

  describe "#update_proxy_settings (private)" do
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
      stub_const("ApplianceEmbeddedAnsible::SETTINGS_FILE", settings_file.path)
      expect(VMDB::Util).to receive(:http_proxy_uri).and_return(proxy_uri)
    end

    it "add current proxy info" do
      subject.send(:update_proxy_settings)
      new_contents = File.read(settings_file.path)
      expect(new_contents).to include("AWX_TASK_ENV['HTTP_PROXY'] = '#{proxy_uri}'\n")
      expect(new_contents).to include("AWX_TASK_ENV['HTTPS_PROXY'] = '#{proxy_uri}'\n")
      expect(new_contents).to include("AWX_TASK_ENV['NO_PROXY'] = '127.0.0.1'\n")
      expect(new_contents).not_to include("'somehost'")
    end
  end
end
