require 'workers/evm_server'

describe EvmServer do
  context "#start" do
    let(:server) { described_class.new }

    before do
      allow(MiqServer).to receive_messages(:running? => false)
      allow(server).to receive(:set_database_application_name)
      allow(server).to receive(:set_process_title)
      allow(PidFile).to receive(:create)
    end

    it "SIGINT" do
      allow(MiqServer).to receive(:start).and_raise(Interrupt)
      expect(server).to receive(:process_hard_signal)
      server.start
    end

    it "SIGTERM" do
      allow(MiqServer).to receive(:start).and_raise(SignalException, "SIGTERM")
      expect(server).to receive(:process_soft_signal)
      server.start
    end

    it "unhandled signal SIGALRM" do
      allow(MiqServer).to receive(:start).and_raise(SignalException, "SIGALRM")
      expect { server.start }.to raise_error(SignalException, "SIGALRM")
    end
  end
end
