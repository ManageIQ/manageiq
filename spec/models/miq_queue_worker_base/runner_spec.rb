describe MiqQueueWorkerBase::Runner do
  context "#get_message_via_drb" do
    let(:server) { EvmSpecHelper.local_miq_server }
    let(:worker) { FactoryGirl.create(:miq_generic_worker, :miq_server => server, :pid => 123) }
    let(:runner) do
      allow_any_instance_of(MiqQueueWorkerBase::Runner).to receive(:sync_active_roles)
      allow_any_instance_of(MiqQueueWorkerBase::Runner).to receive(:sync_config)
      allow_any_instance_of(MiqQueueWorkerBase::Runner).to receive(:set_connection_pool_size)
      described_class.new(:guid => worker.guid)
    end

    it "sets message to 'error' and raises for unhandled exceptions" do
      # simulate what may happen if invalid yaml is deserialized
      allow_any_instance_of(MiqQueue).to receive(:args).and_raise(ArgumentError)
      q1 = FactoryGirl.create(:miq_queue)
      allow(runner)
        .to receive(:worker_monitor_drb)
        .and_return(double(:get_queue_message => [q1.id, q1.lock_version]))

      expect { runner.get_message_via_drb }.to raise_error(StandardError)
      expect(q1.reload.state).to eql(MiqQueue::STATUS_ERROR)
    end
  end
end
