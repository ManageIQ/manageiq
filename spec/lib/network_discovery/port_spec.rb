require 'manageiq/network_discovery/discovery'
require 'ostruct'
require 'benchmark'

RSpec.describe ManageIQ::NetworkDiscovery::Port do
  before do
    @ost = OpenStruct.new
    @ost.ipaddr = '172.16.254.1'
  end

  context '#open?' do
    it 'with an open port' do
      expect(TCPSocket).to receive(:open).and_return(StringIO.new)
      expect(described_class.open?(@ost, 903)).to be_truthy
    end

    it 'with a closed port' do
      expect(TCPSocket).to receive(:open).and_raise(Timeout::Error)
      expect(described_class.open?(@ost, 904)).to be_falsey
    end

    it 'with a changed timeout value' do
      @ost.timeout = 0.001
      allow(TCPSocket).to receive(:open) { sleep 1 }
      ts = Benchmark.realtime do
        expect(described_class.open?(@ost, 123)).to be_falsey
      end
      expect(ts).to be < 0.5
    end
  end

  context '#scan_open' do
    before do
      allow(described_class).to receive(:open?).with(@ost, 902).and_return(true)
      allow(described_class).to receive(:open?).with(@ost, 903).and_return(false)
      allow(described_class).to receive(:open?).with(@ost, 904).and_return(true)
      allow(described_class).to receive(:open?).with(@ost, 905).and_return(false)
    end

    it 'has some open with array of ports' do
      expect(described_class.scan_open(@ost, [902, 903, 904, 905])).to eq([902, 904])
    end

    it 'has some open with range of ports' do
      expect(described_class.scan_open(@ost, 902..905)).to eq([902, 904])
    end
  end
end
