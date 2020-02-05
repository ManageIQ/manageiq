describe MiqSmartProxyWorker::Runner do
  subject { described_class.allocate }

  describe "#ensure_heartbeat_thread_started" do
    let(:thread) { double(Thread) }

    it "starts the heartbeat thread if it has never been started" do
      expect(subject).to receive(:start_heartbeat_thread).and_return(thread)
      subject.ensure_heartbeat_thread_started
      expect(subject.instance_variable_get(:@tid)).to eq(thread)
    end

    it "restarts the heartbeat thread if it has exited" do
      subject.instance_variable_set(:@tid, thread)
      expect(thread).to receive(:alive?).and_return(false)
      expect(thread).to receive(:status).and_return(false)

      new_thread = double(Thread)
      expect(subject).to receive(:start_heartbeat_thread).and_return(new_thread)

      subject.ensure_heartbeat_thread_started
      expect(subject.instance_variable_get(:@tid)).to eq(new_thread)
    end

    it "restarts the heartbeat thread if it has failed" do
      subject.instance_variable_set(:@tid, thread)
      expect(thread).to receive(:alive?).and_return(false)
      expect(thread).to receive(:status).and_return(nil)

      new_thread = double(Thread)
      expect(subject).to receive(:start_heartbeat_thread).and_return(new_thread)

      subject.ensure_heartbeat_thread_started
      expect(subject.instance_variable_get(:@tid)).to eq(new_thread)
    end

    it "kills the heartbeat thread if it is aborting and restarts it" do
      subject.instance_variable_set(:@tid, thread)
      expect(thread).to receive(:alive?).and_return(false)
      expect(thread).to receive(:status).and_return("aborting")
      expect(thread).to receive(:kill)

      new_thread = double(Thread)
      expect(subject).to receive(:start_heartbeat_thread).and_return(new_thread)

      subject.ensure_heartbeat_thread_started
      expect(subject.instance_variable_get(:@tid)).to eq(new_thread)
    end
  end
end
