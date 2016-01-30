describe ManageIQ::Providers::Vmware::InfraManager do
  it ".ems_type" do
    expect(described_class.ems_type).to eq('vmwarews')
  end

  it ".description" do
    expect(described_class.description).to eq('VMware vCenter')
  end

  describe ".metrics_collector_queue_name" do
    it "returns the correct queue name" do
      worker_queue = ManageIQ::Providers::Vmware::InfraManager::MetricsCollectorWorker.default_queue_name
      expect(described_class.metrics_collector_queue_name).to eq(worker_queue)
    end
  end

  context "#validate_remote_console_vmrc_support" do
    before(:each) do
      @ems = FactoryGirl.create(:ems_vmware)
    end

    it "not raise for api_version == 5.0" do
      @ems.update_attributes(:api_version => "5.0", :uid_ems => "2E1C1E82-BD83-4E54-9271-630C6DFAD4D1")
      expect { @ems.validate_remote_console_vmrc_support }.not_to raise_error
    end

    it "raise for api_version == 4.0" do
      @ems.update_attributes(:api_version => "4.0", :uid_ems => "2E1C1E82-BD83-4E54-9271-630C6DFAD4D1")
      expect { @ems.validate_remote_console_vmrc_support }.to raise_error MiqException::RemoteConsoleNotSupportedError
    end

    it "raise for api_version == 4.1" do
      @ems.update_attributes(:api_version => "4.1", :uid_ems => "2E1C1E82-BD83-4E54-9271-630C6DFAD4D1")
      expect { @ems.validate_remote_console_vmrc_support }.to raise_error MiqException::RemoteConsoleNotSupportedError
    end

    it "raise for missing/blank values" do
      @ems.update_attributes(:api_version => "", :uid_ems => "2E1C1E82-BD83-4E54-9271-630C6DFAD4D1")
      expect { @ems.validate_remote_console_vmrc_support }.to raise_error MiqException::RemoteConsoleNotSupportedError
    end
  end

  context "#remote_console_vmrc_support_known?" do
    before(:each) do
      @ems = FactoryGirl.create(:ems_vmware)
    end

    it "true with nothing missing/blank" do
      @ems.update_attributes(:api_version => "5.0", :uid_ems => "2E1C1E82-BD83-4E54-9271-630C6DFAD4D1")
      expect(@ems.remote_console_vmrc_support_known?).to be_truthy
    end

    it "false for missing hostname" do
      @ems.update_attributes(:hostname => nil, :api_version => "5.0", :uid_ems => "2E1C1E82-BD83-4E54-9271-630C6DFAD4D1")
      expect(@ems.remote_console_vmrc_support_known?).not_to be_truthy
    end

    it "false for blank hostname" do
      @ems.update_attributes(:hostname => "", :api_version => "5.0", :uid_ems => "2E1C1E82-BD83-4E54-9271-630C6DFAD4D1")
      expect(@ems.remote_console_vmrc_support_known?).not_to be_truthy
    end

    it "false for missing api_version" do
      @ems.update_attributes(:api_version => nil, :uid_ems => "2E1C1E82-BD83-4E54-9271-630C6DFAD4D1")
      expect(@ems.remote_console_vmrc_support_known?).not_to be_truthy
    end

    it "false for blank api_version" do
      @ems.update_attributes(:api_version => "", :uid_ems => "2E1C1E82-BD83-4E54-9271-630C6DFAD4D1")
      expect(@ems.remote_console_vmrc_support_known?).not_to be_truthy
    end

    it "false for missing uid_ems" do
      @ems.update_attributes(:api_version => "5.0", :uid_ems => nil)
      expect(@ems.remote_console_vmrc_support_known?).not_to be_truthy
    end

    it "false for blank uid_ems" do
      @ems.update_attributes(:api_version => "5.0", :uid_ems => "")
      expect(@ems.remote_console_vmrc_support_known?).not_to be_truthy
    end
  end

  context "handling changes that may require EventCatcher restart" do
    before(:each) do
      guid, server, zone = EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_vmware, :zone => zone)
    end

    it "will restart EventCatcher when ipaddress changes" do
      @ems.update_attributes(:ipaddress => "1.1.1.1")
      assert_event_catcher_restart_queued
    end

    it "will restart EventCatcher when hostname changes" do
      @ems.update_attributes(:hostname => "something else")
      assert_event_catcher_restart_queued
    end

    it "will restart EventCatcher when credentials change" do
      @ems.update_authentication(:default => {:userid => "new_user_id"})
      assert_event_catcher_restart_queued
    end

    it "will not put multiple restarts of the EventCatcher on the queue" do
      @ems.update_attributes(:ipaddress => "1.1.1.1")
      @ems.update_attributes(:hostname => "something else")
      assert_event_catcher_restart_queued
    end

    it "will not restart EventCatcher when name changes" do
      @ems.update_attributes(:name => "something else")
      expect(MiqQueue.count).to eq(0)
    end
  end

  private

  def assert_event_catcher_restart_queued
    q = MiqQueue.where(:method_name => "stop_event_monitor")
    expect(q.length).to eq(1)
    expect(q[0].class_name).to eq("ManageIQ::Providers::Vmware::InfraManager")
    expect(q[0].instance_id).to eq(@ems.id)
    expect(q[0].role).to eq("event")
  end
end
