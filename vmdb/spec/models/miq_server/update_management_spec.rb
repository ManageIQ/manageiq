require "spec_helper"

describe MiqServer do
  before do
    MiqDatabase.seed
    guid, @server, @zone = EvmSpecHelper.create_guid_miq_server_zone
  end

  let(:database)    { MiqDatabase.first }
  let(:reg_system)  { LinuxAdmin::RegistrationSystem }
  let(:yum)         { LinuxAdmin::Yum }

  context "Queue multiple servers" do
    before do
      FactoryGirl.create(:miq_server_not_master, :zone => @zone, :guid => MiqUUID.new_guid)
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
      @server.should_receive(:check_updates).once

      @server.update_registration_status
    end
    it "not rhn_client" do
      @server.should_receive(:attempt_registration).once
      @server.should_receive(:check_updates).once

      @server.update_registration_status
    end
  end

  context "#attempt_registration" do
    it "does not continue if registration fails" do
      @server.should_receive(:register).and_return(false)
      @server.should_not_receive(:attach_products)

      @server.attempt_registration
    end

    it "should not try to enable the repo if already enabled" do
      @server.should_receive(:register).and_return(true)
      @server.should_receive(:attach_products)
      @server.should_receive(:repos_enabled?).and_return(true)
      @server.should_not_receive(:enable_repos)

      @server.attempt_registration
    end

    it "should enable the repo if not enabled" do
      reg_system.should_receive(:enabled_repos).and_return([])
      reg_system.should_receive(:enable_repo).twice
      @server.should_receive(:register).and_return(true)
      @server.should_receive(:attach_products)

      expect(@server.attempt_registration).to be_true
    end
  end

  context "#register" do
    it "already registered" do
      reg_system.stub(:registered?).and_return(true)

      @server.register

      expect(@server.reload).to be_rh_registered
      expect(@server.upgrade_message).to eq("registration successful")
    end

    it "unregistered should use subscription-manager" do
      reg_system.stub(:registered?).once.and_return(false, true)
      LinuxAdmin::SubscriptionManager.should_receive(:register).once.and_return(true)
      File.should_receive(:exists?).once.and_return(true)
      reg_system.should_receive(:registration_type).once

      @server.register

      expect(@server.reload).to be_rh_registered
      expect(@server.upgrade_message).to eq("registration successful")
    end

    it "unregistered should use satellite6" do
      database.update_attribute(:registration_type, "rhn_satellite6")
      database.update_attribute(:registration_server, "https://my-sat6-server.mydomain/katello")

      reg_system.stub(:registered?).once.and_return(false, true)
      LinuxAdmin::SubscriptionManager.should_receive(:register).once.and_return(true)
      File.should_receive(:exists?).once.and_return(true)
      reg_system.should_receive(:registration_type).once

      @server.register

      expect(@server.reload).to be_rh_registered
      expect(@server.upgrade_message).to eq("registration successful")
    end

    it "unregistered should use rhn" do
      database.update_attribute(:registration_type, "rhn_satellite")

      reg_system.stub(:registered?).once.and_return(false, true)
      LinuxAdmin::Rhn.should_receive(:register).once.and_return(true)
      File.should_receive(:exists?).twice.and_return(false, true)
      reg_system.should_receive(:registration_type).once

      @server.register

      expect(@server.reload.rh_registered).to be_true
      expect(@server.upgrade_message).to eq("registration successful")
    end
  end

  context "#attach_products" do
    it "does not attach products for Rhn" do
      database.update_attribute(:registration_type, "rhn_satellite")
      reg_system.should_not_receive(:subscribe)

      @server.attach_products
      expect(@server.upgrade_message).to eq("attaching products")
    end

    it "attaches products for SubscriptionManager" do
      reg_system.should_receive(:subscribe)

      @server.attach_products
      expect(@server.upgrade_message).to eq("attaching products")
    end
  end

  context "#repo_enabled?" do
    it "true" do
      reg_system.should_receive(:enabled_repos).and_return(["abc", database.update_repo_names].flatten)

      expect(@server.repos_enabled?).to be_true
      expect(@server.upgrade_message).to eq("registered")
    end

    it "false" do
      reg_system.should_receive(:enabled_repos).and_return(["abc", "def"])

      expect(@server.repos_enabled?).to be_false
    end
  end

  it "#enable_repos" do
    reg_system.should_receive(:enable_repo).twice

    @server.enable_repos
    expect(@server.upgrade_message).to eq("enabling repo rhel-server-rhscl-6-rpms")
  end

  it "#check_updates" do
    yum.should_receive(:updates_available?).twice.and_return(true)
    yum.should_receive(:version_available).with("cfme-appliance").once.and_return({"cfme-appliance" => "3.1"})

    @server.check_updates

    expect(database.cfme_version_available).to eq("3.1")
  end

  context "#apply_updates" do
    it "will apply cfme updates only with local database" do
      yum.should_receive(:updates_available?).twice.and_return(true)
      yum.should_receive(:version_available).once.and_return({})
      Dir.should_receive(:glob).and_return(["/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release", "/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-beta"])
      LinuxAdmin::Rpm.should_receive(:import_key).with("/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release").and_return(true)
      LinuxAdmin::Rpm.should_receive(:import_key).with("/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-beta").and_return(true)
      EvmDatabase.should_receive(:local?).and_return(true)
      yum.should_receive(:update).once.with("cfme-appliance")

      @server.apply_updates
    end

    it "will apply all updates with remote database" do
      yum.should_receive(:updates_available?).twice.and_return(true)
      yum.should_receive(:version_available).once.and_return({})
      Dir.should_receive(:glob).and_return(["/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release"])
      LinuxAdmin::Rpm.should_receive(:import_key).with("/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release").and_return(true)
      EvmDatabase.should_receive(:local?).and_return(false)
      yum.should_receive(:update).once.with("")

      @server.apply_updates
    end

    it "does not have updates to apply" do
      yum.should_receive(:updates_available?).twice.and_return(false)
      yum.should_receive(:version_available).once.and_return({})

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
end
