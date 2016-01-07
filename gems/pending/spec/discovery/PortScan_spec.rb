require "spec_helper"
require 'discovery/PortScan'

require 'ostruct'
require 'benchmark'

describe PortScanner do
  before(:each) do
    @ost = OpenStruct.new
    @ost.ipaddr = "192.168.252.2" # yoda (ESX)
  end

  context ".portOpen" do
    it "with an open port" do
      expect(TCPSocket).to receive(:open).and_return(StringIO.new)
      expect(described_class.portOpen(@ost, 903)).to be_truthy
    end

    it "with a closed port" do
      expect(TCPSocket).to receive(:open).and_raise(Timeout::Error)
      expect(described_class.portOpen(@ost, 904)).to be_falsey
    end

    it "with a changed timeout value" do
      @ost.timeout = 0.001
      allow(TCPSocket).to receive(:open) { sleep 1 }
      ts = Benchmark.realtime do
        expect(described_class.portOpen(@ost, 123)).to be_falsey
      end
      expect(ts).to be < 0.5
    end
  end

  context ".scanPortArray" do
    before(:each) do
      allow(described_class).to receive(:portOpen).with(@ost, 902).and_return(true)
      allow(described_class).to receive(:portOpen).with(@ost, 903).and_return(true)
      allow(described_class).to receive(:portOpen).with(@ost, 904).and_return(false)
      allow(described_class).to receive(:portOpen).with(@ost, 905).and_return(false)
    end

    it("with all open ports")  { expect(described_class.scanPortArray(@ost, [902, 903])).to eq([902, 903]) }
    it("with some open ports") { expect(described_class.scanPortArray(@ost, [903, 904])).to eq([903]) }
    it("with no open ports")   { expect(described_class.scanPortArray(@ost, [904, 905])).to eq([]) }
  end

  context ".scanPortRange" do
    before(:each) do
      allow(described_class).to receive(:portOpen).with(@ost, 902).and_return(true)
      allow(described_class).to receive(:portOpen).with(@ost, 903).and_return(true)
      allow(described_class).to receive(:portOpen).with(@ost, 904).and_return(false)
      allow(described_class).to receive(:portOpen).with(@ost, 905).and_return(false)
    end

    it("with all open ports")  { expect(described_class.scanPortRange(@ost, 902, 903)).to eq([902, 903]) }
    it("with some open ports") { expect(described_class.scanPortRange(@ost, 903, 904)).to eq([903]) }
    it("with no open ports")   { expect(described_class.scanPortRange(@ost, 904, 905)).to eq([]) }
  end
end
