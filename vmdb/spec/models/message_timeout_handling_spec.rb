require "spec_helper"

describe "Message Timeout Handling" do
  before(:each) do
    @guid = MiqUUID.new_guid
    MiqServer.stub(:my_guid).and_return(@guid)

    @zone       = FactoryGirl.create(:zone)
    @miq_server = FactoryGirl.create(:miq_server, :guid => @guid, :zone => @zone)
    MiqServer.stub(:my_server).and_return(@miq_server)

    @worker = FactoryGirl.create(:miq_ems_refresh_worker_vmware, :miq_server_id => @miq_server.id)
  end

  context "A Worker Handling a Message with a timeout of 3600 seconds" do
    before(:each) do
      MiqQueue.put(
        :msg_timeout => 3600,
        :class_name  => "Vm",
        :role        => "ems_inventory",
        :zone        => @zone.name
      )

      @worker.update_attribute(:last_heartbeat, Time.now.utc)
      @msg = MiqQueue.get(:role => "ems_inventory", :zone => @zone.name)
    end

    it "should not be timed out after 15 minutes" do
      Timecop.travel(15.minutes) do
        time_threshold = @worker.current_timeout
        time_threshold.should == 3600
        time_threshold.seconds.ago.utc.should_not > @worker.last_heartbeat
      end
    end
  end

  context "An MiqServer monitoring Workers, with a Message Queued with a timeout of 3600 seconds" do
    before(:each) do
      @worker.update_attributes(:last_heartbeat => Time.now.utc, :status => 'started')
      @msg = MiqQueue.put(
        :msg_timeout  => 3600,
        :class_name   => "Vm",
        :role         => "ems_inventory",
        :zone         => @zone.name
      )

      @msg.update_attributes(
        :handler_id   => @worker.id,
        :handler_type => 'MiqWorker'
      )
      @miq_server.sync_child_worker_settings
    end

    it "should not be timed out after 15 minutes when in dequeue state" do
      @msg.update_attribute(:state, "dequeue")
      Timecop.travel(15.minutes) do
        time_threshold = @miq_server.get_time_threshold(@worker)
        time_threshold.should == 3610
        time_threshold.seconds.ago.utc.should_not > @worker.last_heartbeat
      end
    end

    it "should be timed out after 15 minutes when in error state" do
      @msg.update_attribute(:state, "error")
      Timecop.travel(15.minutes) do
        time_threshold = @miq_server.get_time_threshold(@worker)
        time_threshold.should == 120
        time_threshold.seconds.ago.utc.should > @worker.last_heartbeat
      end
    end
  end
end
