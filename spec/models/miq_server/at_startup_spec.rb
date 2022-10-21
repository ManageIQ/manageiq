RSpec.describe MiqServer, "::AtStartup" do
  describe ".clean_dequeued_messages" do
    let!(:miq_server) { EvmSpecHelper.local_miq_server }

    context "where worker has a message in dequeue" do
      it "should cleanup message on startup" do
        worker = FactoryBot.create(:miq_ems_refresh_worker, :miq_server => miq_server)
        msg = FactoryBot.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :handler => worker)

        described_class.clean_dequeued_messages

        msg.reload
        expect(msg.state).to eq(MiqQueue::STATE_ERROR)
      end

      it "deletes shutdown_and_exit messages" do
        worker = FactoryBot.create(:miq_ems_refresh_worker, :miq_server => miq_server)
        FactoryBot.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :handler => worker,
                           :method_name => "shutdown_and_exit")
        described_class.clean_dequeued_messages
        expect(MiqQueue.count).to eq 0
      end
    end

    context "where worker on other server has a message in dequeue" do
      it "should not cleanup message on startup" do
        other_miq_server = FactoryBot.create(:miq_server, :zone => miq_server.zone)
        other_worker = FactoryBot.create(:miq_ems_refresh_worker, :miq_server_id => other_miq_server.id)
        msg = FactoryBot.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :handler => other_worker)

        described_class.clean_dequeued_messages

        msg.reload
        expect(msg.state).to eq(MiqQueue::STATE_DEQUEUE)
      end
    end

    context "message in dequeue without a worker" do
      it "should cleanup message on startup" do
        msg = FactoryBot.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE)

        described_class.clean_dequeued_messages

        msg.reload
        expect(msg.state).to eq(MiqQueue::STATE_ERROR)
      end
    end
  end

  it ".log_under_management (private)" do
    ems = FactoryBot.create(:ems_infra)
    FactoryBot.create(:host_vmware, :ext_management_system => ems)
    FactoryBot.create(:vm_vmware, :ext_management_system => ems)
    expect($log).to receive(:info).with(/VMs: \[1\], Hosts: \[1\]/)
    described_class.send(:log_under_management, "")
  end

  it ".log_not_under_management (private)" do
    FactoryBot.create(:host_vmware)
    FactoryBot.create(:vm_vmware)
    expect($log).to receive(:info).with(/VMs: \[1\], Hosts: \[1\]/)
    described_class.send(:log_not_under_management, "")
  end
end
