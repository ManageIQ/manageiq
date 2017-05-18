describe "Queue Management" do
  let(:server) { EvmSpecHelper.local_miq_server }

  describe "#ntp_reload_queue" do
    it "enqueues a message if the server is an appliance, but not a container" do
      expect(MiqEnvironment::Command).to receive(:is_appliance?).and_return(true)
      expect(MiqEnvironment::Command).to receive(:is_container?).and_return(false)

      server.ntp_reload_queue

      expect(ntp_reload_enqueued?).to be_truthy
    end

    it "doesn't enqueue a message if the server is not an appliance" do
      expect(MiqEnvironment::Command).to receive(:is_appliance?).and_return(false)

      server.ntp_reload_queue

      expect(ntp_reload_enqueued?).to be_falsey
    end

    it "doesn't enqueue a message if the server is a container" do
      expect(MiqEnvironment::Command).to receive(:is_appliance?).and_return(true)
      expect(MiqEnvironment::Command).to receive(:is_container?).and_return(true)

      server.ntp_reload_queue

      expect(ntp_reload_enqueued?).to be_falsey
    end
  end

  def ntp_reload_enqueued?
    MiqQueue.find_by(:class_name => "MiqServer", :instance_id => server.id, :method_name => "ntp_reload")
  end
end
