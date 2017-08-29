describe 'VM::Operations' do
  before(:each) do
    @miq_server = EvmSpecHelper.local_miq_server
    @ems        = FactoryGirl.create(:ems_vmware, :zone => @miq_server.zone)
    @vm         = FactoryGirl.create(:vm_vmware, :ems_id => @ems.id)
    ipaddresses = %w(fe80::21a:4aff:fe22:dde5 127.0.0.1)
    allow(@vm).to receive(:ipaddresses).and_return(ipaddresses)

    @hardware = FactoryGirl.create(:hardware)
    @hardware.ipaddresses << '10.142.0.2'
    @hardware.ipaddresses << '35.190.140.48'
  end

  context '#cockpit_url' do
    it '#returns a valid Cockpit url' do
      url = @vm.send(:cockpit_url)
      expect(url).to eq(URI::HTTP.build(:host => "127.0.0.1", :port => 9090).to_s)
    end
  end

  context '#ipv4_address' do
    it 'returns the existing ipv4 address' do
      url = @vm.send(:ipv4_address)
      expect(url).to eq('127.0.0.1')
    end

    context 'cloud providers' do
      before(:each) { @ipaddresses = %w(10.10.1.121 35.190.140.48) }
      it 'returns the public ipv4 address for AWS' do
        ems = FactoryGirl.create(:ems_google, :project => 'manageiq-dev')
        az  = FactoryGirl.create(:availability_zone_google)
        vm = FactoryGirl.create(:vm_google,
                                :ext_management_system => ems,
                                :ems_ref               => 123,
                                :availability_zone     => az,
                                :hardware              => @hardware)
        allow(vm).to receive(:ipaddresses).and_return(@ipaddresses)
        url = vm.send(:ipv4_address)
        expect(url).to eq('35.190.140.48')
      end

      it 'returns the public ipv4 address for GCE' do
        ems = FactoryGirl.create(:ems_amazon)
        vm = FactoryGirl.create(:vm_amazon, :ext_management_system => ems, :hardware => @hardware)
        allow(vm).to receive(:ipaddresses).and_return(@ipaddresses)
        url = vm.send(:ipv4_address)
        expect(url).to eq('35.190.140.48')
      end
    end
  end

  context '#public_address' do
    it 'returns a public ipv4 address' do
      ipaddresses = %w(10.10.1.121 35.190.140.48)
      ems = FactoryGirl.create(:ems_amazon)
      vm = FactoryGirl.create(:vm_amazon, :ext_management_system => ems, :hardware => @hardware)
      allow(vm).to receive(:ipaddresses).and_return(ipaddresses)
      url = vm.send(:public_address)
      expect(url).to eq('35.190.140.48')
    end
  end
end
