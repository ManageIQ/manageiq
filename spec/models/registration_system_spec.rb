describe "RegistrationSystem" do
  before do
    EvmSpecHelper.create_guid_miq_server_zone
    @creds       = {:userid => "SomeUser", :password => "SomePass"}
    @proxy_creds = {:userid => "bob", :password => "pass"}
  end

  context ".available_organizations_queue" do
    it "does not modify original arguments" do
      cloned_creds = @creds.clone
      RegistrationSystem.available_organizations_queue(@creds)
      expect(@creds).to eq(cloned_creds)
    end

    it "validate that a task was created" do
      expect(MiqTask.find(RegistrationSystem.available_organizations_queue(@creds))).to be_truthy
    end

    it "validate that one queue item was created for this task" do
      RegistrationSystem.available_organizations_queue(@creds)
      expect(MiqQueue.count).to eq(1)
    end

    it "validate that the queue item was created with proper args" do
      task = RegistrationSystem.available_organizations_queue(@creds)
      expect(MiqQueue.first.args).to eq([
        {:userid => "SomeUser", :password => "v2:{mJENsyNNOBzjMgTsS0+iRg==}", :task_id => task}
      ])
    end
  end

  context ".available_organizations" do
    it "with valid credentials" do
      expect_any_instance_of(LinuxAdmin::SubscriptionManager).to receive(:organizations).once.with(:username => "SomeUser", :password => "SomePass").and_return("SomeOrg" => {:name => "SomeOrg", :key => "1234567"}, "SomeOrg2" => {:name => "SomeOrg2", :key => "12345672"})
      expect(RegistrationSystem.available_organizations(@creds)).to eq("SomeOrg" => "1234567", "SomeOrg2" => "12345672")
    end

    it "with invalid credentials" do
      expect_any_instance_of(LinuxAdmin::SubscriptionManager).to receive(:organizations).once.and_raise(LinuxAdmin::CredentialError, "Invalid username or password")
      expect { RegistrationSystem.available_organizations(@creds) }.to raise_error(LinuxAdmin::CredentialError)
    end

    it "with no options" do
      MiqDatabase.seed
      MiqDatabase.first.update_authentication(:registration => @creds)
      MiqDatabase.first.update_authentication(:registration_http_proxy => @proxy_creds)
      MiqDatabase.first.update_attributes(
        :registration_server            => "http://abc.net",
        :registration_http_proxy_server => "1.1.1.1"
      )
      expect_any_instance_of(LinuxAdmin::SubscriptionManager).to receive(:organizations).once.with(:username => "SomeUser", :password => "SomePass", :server_url => "http://abc.net", :registration_type => "sm_hosted", :proxy_address => "1.1.1.1", :proxy_username => "bob", :proxy_password => "pass").and_return("SomeOrg" => {:name => "SomeOrg", :key => "1234567"}, "SomeOrg2" => {:name => "SomeOrg2", :key => "12345672"})
      expect(RegistrationSystem.available_organizations).to eq("SomeOrg" => "1234567", "SomeOrg2" => "12345672")
    end
  end

  context ".verify_credentials_queue" do
    it "does not modify original arguments" do
      cloned_creds = @creds.clone
      RegistrationSystem.verify_credentials_queue(@creds)
      expect(@creds).to eq(cloned_creds)
    end

    it "validate that a task was created" do
      expect(MiqTask.find(RegistrationSystem.verify_credentials_queue(@creds))).to be_truthy
    end

    it "validate that one queue item was created for this task" do
      RegistrationSystem.verify_credentials_queue(@creds)
      expect(MiqQueue.count).to eq(1)
    end

    it "validate that the queue item was created with proper args" do
      task = RegistrationSystem.verify_credentials_queue(@creds)
      expect(MiqQueue.first.args).to eq([
        {:userid => "SomeUser", :password => "v2:{mJENsyNNOBzjMgTsS0+iRg==}", :task_id => task}
      ])
    end
  end

  context ".verify_credentials" do
    it "with valid credentials" do
      expect(LinuxAdmin::RegistrationSystem).to receive(:validate_credentials).once.with(:username => "SomeUser", :password => "SomePass").and_return(true)
      expect(RegistrationSystem.verify_credentials(@creds)).to be_truthy
    end

    it "with invalid credentials" do
      expect(LinuxAdmin::RegistrationSystem).to receive(:validate_credentials).once.and_raise(LinuxAdmin::CredentialError, "Invalid username or password")
      expect(RegistrationSystem.verify_credentials(@creds)).to be_falsey
    end

    it "should rescue NotImplementedError" do
      allow_any_instance_of(LinuxAdmin::Rhn).to receive_messages(:registered? => true)
      expect(RegistrationSystem.verify_credentials(@creds)).to be_falsey
    end

    it "with no options" do
      MiqDatabase.seed
      MiqDatabase.first.update_authentication(:registration => @creds)
      MiqDatabase.first.update_authentication(:registration_http_proxy => @proxy_creds)
      MiqDatabase.first.update_attributes(
        :registration_server            => "http://abc.net",
        :registration_http_proxy_server => "1.1.1.1"
      )
      expect(LinuxAdmin::RegistrationSystem).to receive(:validate_credentials).once.with(:username => "SomeUser", :password => "SomePass", :server_url => "http://abc.net", :registration_type => "sm_hosted", :proxy_address => "1.1.1.1", :proxy_username => "bob", :proxy_password => "pass").and_return(true)
      expect(RegistrationSystem.verify_credentials).to be_truthy
    end
  end
end
