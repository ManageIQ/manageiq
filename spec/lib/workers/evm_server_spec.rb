require "workers/evm_server"

describe EvmServer do
  let(:server) { EvmSpecHelper.local_miq_server }

  describe "#monitor_loop" do
    it "calls shutdown_and_exit if SIGTERM is raised" do
      expect(server).to receive(:monitor).and_raise(SignalException, "SIGTERM")
      expect(server).to receive(:shutdown_and_exit)

      described_class.new.monitor_loop(server)
    end

    it "kills the server and exits if SIGINT is raised" do
      expect(server).to receive(:monitor).and_raise(Interrupt)
      expect(MiqServer).to receive(:kill)
      expect(server).to receive(:exit).with(1)

      described_class.new.monitor_loop(server)
    end
  end
end
