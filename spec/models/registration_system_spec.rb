require "tempfile"

RSpec.describe RegistrationSystem do
  let(:creds) { {:userid => "SomeUser", :password => "SomePass"} }
  let(:proxy_creds) { {:userid => "bob", :password => "pass"} }
  before do
    EvmSpecHelper.create_guid_miq_server_zone
  end

  context ".available_organizations_queue" do
    it "does not modify original arguments" do
      cloned_creds = creds.clone
      RegistrationSystem.available_organizations_queue(creds)
      expect(creds).to eq(cloned_creds)
    end

    it "validate that a task was created" do
      expect(MiqTask.find(RegistrationSystem.available_organizations_queue(creds))).to be_truthy
    end

    it "validate that one queue item was created for this task" do
      RegistrationSystem.available_organizations_queue(creds)
      expect(MiqQueue.count).to eq(1)
    end

    it "validate that the queue item was created with proper args" do
      task = RegistrationSystem.available_organizations_queue(creds)
      expect(MiqQueue.first.args).to eq([
        {:userid => "SomeUser", :password => "v2:{mJENsyNNOBzjMgTsS0+iRg==}", :task_id => task}
      ])
    end
  end

  context ".available_organizations" do
    it "with valid credentials" do
      expect_any_instance_of(LinuxAdmin::SubscriptionManager).to receive(:organizations).once.with(:username => "SomeUser", :password => "SomePass").and_return("SomeOrg" => {:name => "SomeOrg", :key => "1234567"}, "SomeOrg2" => {:name => "SomeOrg2", :key => "12345672"})
      expect(RegistrationSystem.available_organizations(creds)).to eq("SomeOrg" => "1234567", "SomeOrg2" => "12345672")
    end

    it "with invalid credentials" do
      expect_any_instance_of(LinuxAdmin::SubscriptionManager).to receive(:organizations).once.and_raise(LinuxAdmin::CredentialError, AwesomeSpawn::CommandResult.new("command_line", "Invalid username or password", "Invalid username or password", 1))
      expect { RegistrationSystem.available_organizations(creds) }.to raise_error(LinuxAdmin::CredentialError)
    end

    it "with no options" do
      MiqDatabase.seed
      MiqDatabase.first.update_authentication(:registration => creds)
      MiqDatabase.first.update_authentication(:registration_http_proxy => proxy_creds)
      MiqDatabase.first.update(
        :registration_server            => "http://abc.net",
        :registration_http_proxy_server => "1.1.1.1"
      )
      expect_any_instance_of(LinuxAdmin::SubscriptionManager).to receive(:organizations).once.with(:username => "SomeUser", :password => "SomePass", :server_url => "http://abc.net", :registration_type => "sm_hosted", :proxy_address => "1.1.1.1", :proxy_username => "bob", :proxy_password => "pass").and_return("SomeOrg" => {:name => "SomeOrg", :key => "1234567"}, "SomeOrg2" => {:name => "SomeOrg2", :key => "12345672"})
      expect(RegistrationSystem.available_organizations).to eq("SomeOrg" => "1234567", "SomeOrg2" => "12345672")
    end
  end

  context ".verify_credentials_queue" do
    it "does not modify original arguments" do
      cloned_creds = creds.clone
      RegistrationSystem.verify_credentials_queue(creds)
      expect(creds).to eq(cloned_creds)
    end

    it "validate that a task was created" do
      expect(MiqTask.find(RegistrationSystem.verify_credentials_queue(creds))).to be_truthy
    end

    it "validate that one queue item was created for this task" do
      RegistrationSystem.verify_credentials_queue(creds)
      expect(MiqQueue.count).to eq(1)
    end

    it "validate that the queue item was created with proper args" do
      task = RegistrationSystem.verify_credentials_queue(creds)
      expect(MiqQueue.first.args).to eq([
        {:userid => "SomeUser", :password => "v2:{mJENsyNNOBzjMgTsS0+iRg==}", :task_id => task}
      ])
    end
  end

  context ".verify_credentials" do
    it "with valid credentials" do
      expect(LinuxAdmin::RegistrationSystem).to receive(:validate_credentials).once.with(:username => "SomeUser", :password => "SomePass").and_return(true)
      expect(RegistrationSystem.verify_credentials(creds)).to be_truthy
    end

    it "with invalid credentials" do
      expect(LinuxAdmin::RegistrationSystem).to receive(:validate_credentials).once.and_raise(LinuxAdmin::CredentialError, AwesomeSpawn::CommandResult.new("command_line", "Invalid username or password", "Invalid username or password", 1))
      expect(RegistrationSystem.verify_credentials(creds)).to be_falsey
    end

    it "should rescue NotImplementedError" do
      allow(LinuxAdmin::RegistrationSystem).to receive(:registration_type_uncached).and_return(LinuxAdmin::RegistrationSystem)
      expect(RegistrationSystem.verify_credentials(creds)).to be_falsey
    end

    it "with no options" do
      MiqDatabase.seed
      MiqDatabase.first.update_authentication(:registration => creds)
      MiqDatabase.first.update_authentication(:registration_http_proxy => proxy_creds)
      MiqDatabase.first.update(
        :registration_server            => "http://abc.net",
        :registration_http_proxy_server => "1.1.1.1"
      )
      expect(LinuxAdmin::RegistrationSystem).to receive(:validate_credentials).once.with(:username => "SomeUser", :password => "SomePass", :server_url => "http://abc.net", :registration_type => "sm_hosted", :proxy_address => "1.1.1.1", :proxy_username => "bob", :proxy_password => "pass").and_return(true)
      expect(RegistrationSystem.verify_credentials).to be_truthy
    end
  end

  describe ".update_rhsm_conf_queue" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      @proxy_args = {:registration_http_proxy_server   => "192.0.2.0:myport",
                     :registration_http_proxy_username => "my_dummy_username",
                     :registration_http_proxy_password => "my_dummy_password"}.freeze

      @miq_region = FactoryBot.create(:miq_region, :region => 1)
      allow(MiqRegion).to receive(:my_region).and_return(@miq_region)
    end

    it "does not modify original arguments" do
      expect { RegistrationSystem.update_rhsm_conf_queue(@proxy_args) }.to_not raise_error
    end

    it "validate that a message was queued for each server in the region" do
      RegistrationSystem.update_rhsm_conf_queue(@proxy_args)
      MiqRegion.my_region.miq_servers.each do |server|
        expect(MiqQueue.exists?(:server_guid => server.guid,
                                :class_name  => "RegistrationSystem",
                                :method_name => "update_rhsm_conf")).to be_truthy
      end
      expect(MiqQueue.count).to eq(2)
    end

    it "validate that the queue item was created with proper args" do
      RegistrationSystem.update_rhsm_conf_queue(@proxy_args)
      MiqRegion.my_region.miq_servers.each do |server|
        expect(MiqQueue.where(:server_guid => server.guid,
                              :class_name  => "RegistrationSystem",
                              :method_name => "update_rhsm_conf").first.args.first)
          .to include(:registration_http_proxy_server   => "192.0.2.0:myport",
                      :registration_http_proxy_username => "my_dummy_username",
                      :registration_http_proxy_password => "v2:{x/Avf/y0mnK5CdhEXjxn05xLp6MQn1l0IMOTDVBvIg8=}")
      end
    end
  end

  describe ".update_rhsm_conf" do
    let(:original_rhsm_conf) do
      <<-EOT.strip_heredoc
        # Set to 1 to disable certificate validation:
        insecure = 0

        # Set the depth of certs which should be checked
        # when validating a certificate
        ssl_verify_depth = 3

        # an http proxy server to use
        proxy_hostname =

        # port for http proxy server
        proxy_port =

        # user name for authenticating to an http proxy, if needed
        proxy_user =

        # password for basic http proxy auth, if needed
        proxy_password =

      EOT
    end

    let(:updated_rhsm_conf) do
      <<-EOT.strip_heredoc
        # Set to 1 to disable certificate validation:
        insecure = 0

        # Set the depth of certs which should be checked
        # when validating a certificate
        ssl_verify_depth = 3

        # an http proxy server to use
        proxy_hostname = ProxyHostnameValue

        # port for http proxy server
        proxy_port = 0

        # user name for authenticating to an http proxy, if needed
        proxy_user = my_dummy_username

        # password for basic http proxy auth, if needed
        proxy_password = my_dummy_password

      EOT
    end

    let(:rhsm_conf) { Tempfile.new }

    before do
      stub_const("RegistrationSystem::RHSM_CONFIG_FILE", rhsm_conf.path)
      rhsm_conf.write(original_rhsm_conf)
      rhsm_conf.close
    end

    after do
      FileUtils.rm_f(rhsm_conf)
      FileUtils.rm_f("#{rhsm_conf.path}.miq_orig")
    end

    context "will save then update the original config file" do
      ["", "http://", "https://"].each do |prefix|
        ["proxy.example.com", "192.0.2.0", "[2001:db8::]"].each do |address|
          params = {
            :registration_http_proxy_server   => "#{prefix}#{address}:0",
            :registration_http_proxy_username => "my_dummy_username",
            :registration_http_proxy_password => "my_dummy_password"
          }

          it "with #{params[:registration_http_proxy_server]}" do
            RegistrationSystem.update_rhsm_conf(params)
            expect(File.read("#{rhsm_conf.path}.miq_orig")).to eq(original_rhsm_conf)
            expect(File.read(rhsm_conf)).to eq(updated_rhsm_conf.sub(/ProxyHostnameValue/, address))
          end
        end
      end
    end

    it "with no proxy server will not update the rhsm config file" do
      RegistrationSystem.update_rhsm_conf(:registration_http_proxy_server => nil)
      expect(File.read(rhsm_conf)).to eq(original_rhsm_conf)
    end

    it "with no options will use database valuses" do
      MiqDatabase.seed
      MiqDatabase.first.update(
        :registration_http_proxy_server => "192.0.2.0:0"
      )
      RegistrationSystem.update_rhsm_conf
      expect(File.read(rhsm_conf)).to include("proxy_hostname = 192.0.2.0", "proxy_port = 0")
    end
  end
end
