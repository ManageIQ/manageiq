require 'manageiq/network_discovery/discovery'
require 'ostruct'
require 'util/miq-ipmi'

RSpec.describe ManageIQ::NetworkDiscovery::Discovery do
  context '#scan_host' do
    let(:ost) { OpenStruct.new(:discover_types => [:ipmi], :ipaddr => '127.0.0.1', :hypervisor => []) }
    it 'hypervisor is ipmi when available' do
      allow(MiqIPMI).to receive(:is_available?).and_return(true)
      described_class.scan_host(ost)

      expect(ost.hypervisor).to eql([:ipmi])
    end

    it 'no hypervisor unless ipmi is available' do
      allow(MiqIPMI).to receive(:is_available?).and_return(false)
      described_class.scan_host(ost)

      expect(ost.hypervisor).to eql([])
    end
  end
end
