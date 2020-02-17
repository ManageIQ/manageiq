RSpec.describe MiqQueueWorkerBase::Runner do
  context "#get_message_via_drb" do
    let(:server) { EvmSpecHelper.local_miq_server }
    let(:worker) { FactoryBot.create(:miq_generic_worker, :miq_server => server, :pid => 123) }
    let(:runner) do
      allow_any_instance_of(MiqQueueWorkerBase::Runner).to receive(:sync_config)
      allow_any_instance_of(MiqQueueWorkerBase::Runner).to receive(:set_connection_pool_size)
      described_class.new(:guid => worker.guid)
    end

    it "sets message to 'error' and raises for unhandled exceptions" do
      # simulate what may happen if invalid yaml is deserialized
      allow_any_instance_of(MiqQueue).to receive(:args).and_raise(ArgumentError)
      q1 = FactoryBot.create(:miq_queue)
      allow(runner)
        .to receive(:worker_monitor_drb)
        .and_return(double(:get_queue_message => [q1.id, q1.lock_version]))

      expect { runner.get_message_via_drb }.to raise_error(StandardError)
      expect(q1.reload.state).to eql(MiqQueue::STATUS_ERROR)
    end
  end

  describe "#dequeue_method_via_drb?" do
    let(:server) { EvmSpecHelper.local_miq_server }
    let(:worker) { FactoryBot.create(:miq_generic_worker, :miq_server => server) }
    let(:runner) do
      described_class.allocate.tap do |r|
        r.worker = worker
        r.instance_variable_set(:@server, server)
      end
    end

    it "returns false when the instance variable is not :drb" do
      runner.instance_variable_set(:@dequeue_method, :sql)
      expect(runner.dequeue_method_via_drb?).to be_falsey
    end

    context "when the instance variable is set to :drb" do
      before { runner.instance_variable_set(:@dequeue_method, :drb) }

      it "returns false if the server's drb uri is nil" do
        server.update(:drb_uri => nil)
        expect(runner.dequeue_method_via_drb?).to be_falsey
      end

      context "with a drb uri" do
        let(:drb_object) { instance_double(DRbObject) }

        before do
          server.update(:drb_uri => "drbunix:///tmp/worker_monitor20200211-24337-1ma102h")
          expect(runner).to receive(:worker_monitor_drb).and_return(drb_object)
        end

        it "returns false when the drb server is not accessible" do
          expect(drb_object).to receive(:respond_to?).with(:register_worker).and_raise(DRb::DRbError)
          expect(runner.dequeue_method_via_drb?).to be_falsey
        end

        it "returns true when the server is accessible" do
          expect(drb_object).to receive(:respond_to?).with(:register_worker).and_return(true)
          expect(runner.dequeue_method_via_drb?).to be_truthy
        end
      end
    end
  end
end
