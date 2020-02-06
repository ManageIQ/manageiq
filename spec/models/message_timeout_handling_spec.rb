RSpec.describe "Message Timeout Handling" do
  before do
    @guid = SecureRandom.uuid
    allow(MiqServer).to receive(:my_guid).and_return(@guid)

    @zone       = FactoryBot.create(:zone)
    @miq_server = FactoryBot.create(:miq_server, :guid => @guid, :zone => @zone)
    allow(MiqServer).to receive(:my_server).and_return(@miq_server)

    @worker = FactoryBot.create(:ems_refresh_worker_amazon, :miq_server_id => @miq_server.id)
    MiqWorker.my_guid = @worker.guid
  end

  context "A Worker Handling a Message with a timeout of 3600 seconds" do
    before do
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
        expect(time_threshold).to eq(3600)
        expect(time_threshold.seconds.ago.utc).not_to be > @worker.last_heartbeat
      end
    end
  end

  context "An MiqServer monitoring Workers, with a Message Queued with a timeout of 3600 seconds" do
    before do
      @worker.update(:last_heartbeat => Time.now.utc, :status => 'started')
      @msg = MiqQueue.put(
        :msg_timeout => 3600,
        :class_name  => "Vm",
        :role        => "ems_inventory",
        :zone        => @zone.name
      )

      @msg.update(
        :handler_id   => @worker.id,
        :handler_type => 'MiqWorker'
      )
      MiqWorkerType.seed
      @miq_server.sync_child_worker_settings
    end

    it "should not be timed out after 15 minutes when in dequeue state" do
      @msg.update_attribute(:state, "dequeue")
      Timecop.travel(15.minutes) do
        time_threshold = @miq_server.get_time_threshold(@worker)
        expect(time_threshold).to eq(3610)
        expect(time_threshold.seconds.ago.utc).not_to be > @worker.last_heartbeat
      end
    end

    it "should be timed out after 15 minutes when in error state" do
      @msg.update_attribute(:state, "error")
      Timecop.travel(15.minutes) do
        time_threshold = @miq_server.get_time_threshold(@worker)
        expect(time_threshold).to eq(120)
        expect(time_threshold.seconds.ago.utc).to be > @worker.last_heartbeat
      end
    end
  end
end
