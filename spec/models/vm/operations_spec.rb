describe 'VM::Operations' do
  before(:each) do
    miq_server = EvmSpecHelper.local_miq_server
    @ems       = FactoryGirl.create(:ems_vmware, :zone => miq_server.zone)
    @vm        = FactoryGirl.create(:vm_vmware, :ems_id => @ems.id)
    allow(@vm).to receive(:ipaddresses).and_return(@ipaddresses)
  end

  context '#cockpit_url' do
    it '#returns a valid Cockpit url' do
      @ipaddresses = %w(fe80::21a:4aff:fe22:dde5 127.0.0.1)
      expect(@vm).to receive(:cockpit_url).and_return('http://127.0.0.1:9090')
      @vm.send(:cockpit_url)
    end
  end

  context '#ipv4_address' do
    after(:each) { @vm.send(:return_ipv4_address) }

    it 'returns the existing ipv4 address' do
      @ipaddresses = %w(fe80::21a:4aff:fe22:dde5 127.0.0.1)
      expect(@vm).to receive(:return_ipv4_address).and_return('127.0.0.1')
    end
  end
end
