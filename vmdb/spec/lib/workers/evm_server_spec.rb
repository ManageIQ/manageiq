require "spec_helper"

require 'workers/evm_server'

describe EvmServer do
  context "#start" do
    let(:server) { described_class.new }

    before do
      MiqServer.stub(:running? => false)
      PidFile.stub(:create)
    end

    it "SIGINT" do
      MiqServer.stub(:start).and_raise(Interrupt)
      server.should_receive(:process_hard_signal)
      server.start
    end

    it "SIGTERM" do
      MiqServer.stub(:start).and_raise(SignalException, "SIGTERM")
      server.should_receive(:process_soft_signal)
      server.start
    end

    it "unhandled signal SIGALRM" do
      MiqServer.stub(:start).and_raise(SignalException, "SIGALRM")
      expect { server.start }.to raise_error(SignalException, "SIGALRM")
    end
  end
end
