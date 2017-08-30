describe MiqServer, "::AtStartup" do
  describe ".clean_dequeued_messages" do
    before do
      _guid, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone
    end

    context "where worker has a message in dequeue" do
      it "should cleanup message on startup" do
        worker = FactoryGirl.create(:miq_ems_refresh_worker, :miq_server_id => @miq_server.id)
        msg = FactoryGirl.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :handler => worker)

        described_class.clean_dequeued_messages

        msg.reload
        expect(msg.state).to eq(MiqQueue::STATE_ERROR)
      end
    end

    context "where worker on other server has a message in dequeue" do
      it "should not cleanup message on startup" do
        other_miq_server = FactoryGirl.create(:miq_server, :zone => @zone)
        other_worker = FactoryGirl.create(:miq_ems_refresh_worker, :miq_server_id => other_miq_server.id)
        msg = FactoryGirl.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :handler => other_worker)

        described_class.clean_dequeued_messages

        msg.reload
        expect(msg.state).to eq(MiqQueue::STATE_DEQUEUE)
      end
    end

    context "message in dequeue without a worker" do
      it "should cleanup message on startup" do
        msg = FactoryGirl.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE)

        described_class.clean_dequeued_messages

        msg.reload
        expect(msg.state).to eq(MiqQueue::STATE_ERROR)
      end
    end
  end

  it ".log_not_under_management (private)" do
    MiqRegion.seed
    FactoryGirl.create(:host_vmware)
    FactoryGirl.create(:vm_vmware)
    expect($log).to receive(:info).with(/VMs: \[1\], Hosts: \[1\]/)
    described_class.send(:log_not_under_management, "")
  end
end
