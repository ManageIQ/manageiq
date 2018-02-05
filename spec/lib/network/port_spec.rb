require 'manageiq/network/discovery'
require 'ostruct'
require 'benchmark'

RSpec.describe ManageIQ::Network::Port do
  before(:each) do
    @ost = OpenStruct.new
    @ost.ipaddr = "192.168.252.2" # yoda (ESX)
  end

  context "#open?" do
    it "with an open port" do
      expect(TCPSocket).to receive(:open).and_return(StringIO.new)
      expect(described_class.open?(@ost, 903)).to be_truthy
    end

    it "with a closed port" do
      expect(TCPSocket).to receive(:open).and_raise(Timeout::Error)
      expect(described_class.open?(@ost, 904)).to be_falsey
    end

    it "with a changed timeout value" do
      @ost.timeout = 0.001
      allow(TCPSocket).to receive(:open) { sleep 1 }
      ts = Benchmark.realtime do
        expect(described_class.open?(@ost, 123)).to be_falsey
      end
      expect(ts).to be < 0.5
    end
  end

  context ".scan_array" do
    before(:each) do
      allow(described_class).to receive(:open?).with(@ost, 902).and_return(true)
      allow(described_class).to receive(:open?).with(@ost, 903).and_return(true)
      allow(described_class).to receive(:open?).with(@ost, 904).and_return(false)
      allow(described_class).to receive(:open?).with(@ost, 905).and_return(false)
    end

    it("with all open ports")  { expect(described_class.scan_array(@ost, [902, 903])).to eq([902, 903]) }
    it("with some open ports") { expect(described_class.scan_array(@ost, [903, 904])).to eq([903]) }
    it("with no open ports")   { expect(described_class.scan_array(@ost, [904, 905])).to eq([]) }
  end

  context ".scan_range" do
    before(:each) do
      allow(described_class).to receive(:open?).with(@ost, 902).and_return(true)
      allow(described_class).to receive(:open?).with(@ost, 903).and_return(true)
      allow(described_class).to receive(:open?).with(@ost, 904).and_return(false)
      allow(described_class).to receive(:open?).with(@ost, 905).and_return(false)
    end

    it("with all open ports")  { expect(described_class.scan_range(@ost, 902, 903)).to eq([902, 903]) }
    it("with some open ports") { expect(described_class.scan_range(@ost, 903, 904)).to eq([903]) }
    it("with no open ports")   { expect(described_class.scan_range(@ost, 904, 905)).to eq([]) }
  end
end
