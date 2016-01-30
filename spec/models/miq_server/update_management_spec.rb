describe MiqServer do
  before do
    MiqDatabase.seed
    _, @server, = EvmSpecHelper.create_guid_miq_server_zone
  end

  let(:database)    { MiqDatabase.first }
  let(:reg_system)  { LinuxAdmin::RegistrationSystem }
  let(:yum)         { LinuxAdmin::Yum }

  context "Queue multiple servers" do
    before do
      FactoryGirl.create(:miq_server, :zone => @server.zone)
    end

    it ".queue_update_registration_status" do
      described_class.queue_update_registration_status(described_class.all.collect(&:id))

      expect(MiqQueue.where(:method_name => "update_registration_status").count).to eq(2)
    end

    it ".queue_check_updates" do
      described_class.queue_check_updates(described_class.all)

      expect(MiqQueue.where(:method_name => "check_updates").count).to eq(2)
    end

    it ".queue_apply_updates" do
      described_class.queue_apply_updates(described_class.all)

      expect(MiqQueue.where(:method_name => "apply_updates").count).to eq(2)
    end
  end

  context "Queue a single server" do
    it "#queue_update_registration_status" do
      @server.queue_update_registration_status

      expect(MiqQueue.where(:method_name => "update_registration_status").count).to eq(1)
    end

    it "#queue_check_updates" do
      @server.queue_check_updates

      expect(MiqQueue.where(:method_name => "check_updates").count).to eq(1)
    end

    it "#queue_apply_updates" do
      @server.queue_apply_updates

      expect(MiqQueue.where(:method_name => "apply_updates").count).to eq(1)
    end
  end

  context "#update_registration_status" do
    it "rhn_client" do
      @server.update_attribute(:rhn_mirror, true)
      expect(@server).to receive(:check_updates).once

      @server.update_registration_status
    end
    it "not rhn_client" do
      expect(@server).to receive(:attempt_registration).once
      expect(@server).to receive(:check_updates).once

      @server.update_registration_status
    end
  end

  context "#attempt_registration" do
    it "does not continue if registration fails" do
      expect(@server).to receive(:register).and_return(false)
      expect(@server).not_to receive(:attach_products)

      @server.attempt_registration
    end

    it "should not try to enable the repo if already enabled" do
      expect(@server).to receive(:register).and_return(true)
      expect(@server).to receive(:attach_products)
      expect(@server).to receive(:repos_enabled?).and_return(true)
      expect(@server).not_to receive(:enable_repos)

      @server.attempt_registration
    end

    it "should enable the repo if not enabled" do
      expect(@server).to receive(:register).and_return(true)
      expect(@server).to receive(:attach_products)
      expect(reg_system).to receive(:enabled_repos).and_return([], [], database.update_repo_name.split)
      expect(@server).to receive(:enable_repos).twice

      @server.attempt_registration
    end
  end

  context "#register" do
    let(:default_params) { {:server_url => "subscription.rhn.redhat.com"} }
    it "already registered" do
      allow(reg_system).to receive(:registered?).and_return(true)

      @server.register

      expect(@server.reload).to be_rh_registered
      expect(@server.upgrade_message).to eq("registration successful")
    end

    it "unregistered should use subscription-manager" do
      allow(reg_system).to receive(:registered?).once.and_return(false, true)
      expect(LinuxAdmin::SubscriptionManager).to receive(:register).once.with(default_params).and_return(true)
      expect(reg_system).to receive(:registration_type).once

      @server.register

      expect(@server.reload).to be_rh_registered
      expect(@server.upgrade_message).to eq("registration successful")
    end

    it "unregistered should use satellite6" do
      expected_params = {:server_url => "https://my-sat6-server.mydomain", :environment => "Library"}

      database.update_attribute(:registration_type, "rhn_satellite6")
      database.update_attribute(:registration_server, expected_params[:server_url])

      allow(reg_system).to receive(:registered?).once.and_return(false, true)
      expect(LinuxAdmin::SubscriptionManager).to receive(:register).once.with(expected_params).and_return(true)
      expect(reg_system).to receive(:registration_type).once

      @server.register

      expect(@server.reload).to be_rh_registered
      expect(@server.upgrade_message).to eq("registration successful")
    end
  end

  context "#attach_products" do
    it "attaches products for SubscriptionManager" do
      expect(reg_system).to receive(:subscribe)

      @server.attach_products
      expect(@server.upgrade_message).to eq("attaching products")
    end
  end

  context "#repo_enabled?" do
    it "true" do
      expect(reg_system).to receive(:enabled_repos).and_return(["abc", database.update_repo_names].flatten)

      expect(@server.repos_enabled?).to be_truthy
      expect(@server.upgrade_message).to eq("registered")
    end

    it "false" do
      expect(reg_system).to receive(:enabled_repos).and_return(["abc", "def"])

      expect(@server.repos_enabled?).to be_falsey
    end
  end

  it "#enable_repos" do
    expect(reg_system).to receive(:enable_repo).twice

    @server.enable_repos
    expect(@server.upgrade_message).to eq("enabling rhel-server-rhscl-7-rpms")
  end

  it "#check_updates" do
    expect(yum).to receive(:updates_available?).twice.and_return(true)
    expect(yum).to receive(:version_available).with("cfme-appliance").once.and_return({"cfme-appliance" => "3.1"})
    allow(MiqDatabase).to receive_messages(:postgres_package_name => "postgresql-server")

    @server.check_updates

    expect(database.cfme_version_available).to eq("3.1")
  end

  context "#apply_updates" do
    before do
      allow(MiqDatabase).to receive_messages(:postgres_package_name => "postgresql-server")
    end

    it "will apply cfme updates only with local database" do
      expect(yum).to receive(:updates_available?).twice.and_return(true)
      expect(yum).to receive(:version_available).once.and_return({})
      expect(Dir).to receive(:glob).and_return(["/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release", "/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-beta"])
      expect(LinuxAdmin::Rpm).to receive(:import_key).with("/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release").and_return(true)
      expect(LinuxAdmin::Rpm).to receive(:import_key).with("/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-beta").and_return(true)
      expect(EvmDatabase).to receive(:local?).and_return(true)
      expect(yum).to receive(:update).once.with("cfme-appliance")

      @server.apply_updates
    end

    it "will apply all updates with remote database" do
      expect(yum).to receive(:updates_available?).twice.and_return(true)
      expect(yum).to receive(:version_available).once.and_return({})
      expect(Dir).to receive(:glob).and_return(["/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release"])
      expect(LinuxAdmin::Rpm).to receive(:import_key).with("/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release").and_return(true)
      expect(EvmDatabase).to receive(:local?).and_return(false)
      expect(yum).to receive(:update).once.with(no_args)

      @server.apply_updates
    end

    it "does not have updates to apply" do
      expect(yum).to receive(:updates_available?).twice.and_return(false)
      expect(yum).to receive(:version_available).once.and_return({})
      allow(MiqDatabase).to receive_messages(:postgres_package_name => "postgresql-server")

      @server.apply_updates
    end
  end

  context "#cfme_available_update" do
    before do
      @server.update_attribute(:version, "1.2.3.4")
    end

    it "with nil version available" do
      database.update_attribute(:cfme_version_available, nil)

      expect(@server.cfme_available_update).to be_nil
    end

    it "with short version available" do
      database.update_attribute(:cfme_version_available, "1.2.3")

      expect(@server.cfme_available_update).to be_nil
    end

    it "with equal versions" do
      database.update_attribute(:cfme_version_available, "1.2.3.4")

      expect(@server.cfme_available_update).to be_nil
    end

    it "with newer build available" do
      database.update_attribute(:cfme_version_available, "1.2.3.5")

      expect(@server.cfme_available_update).to eq("build")
    end

    it "with newer major available" do
      database.update_attribute(:cfme_version_available, "2.0.0.0")

      expect(@server.cfme_available_update).to eq("major")
    end
  end

  context "private" do
    it "#assemble_registration_options" do
      database.update_authentication(:registration => {:userid => "registration_user", :password => "registration_password"})
      database.update_authentication(:registration_http_proxy => {:userid => "proxy_user", :password => "proxy_password"})
      database.update_attributes(
        :registration_organization      => "my_org",
        :registration_http_proxy_server => "my_proxy:port",
        :registration_server            => "subscription.example.com",
      )

      options = @server.send(:assemble_registration_options)

      expect(options).to eq(
        :username       => "registration_user",
        :password       => "registration_password",
        :proxy_address  => "my_proxy:port",
        :proxy_password => "proxy_password",
        :proxy_username => "proxy_user",
        :org            => "my_org",
        :server_url     => "subscription.example.com",
      )
    end
  end
end
