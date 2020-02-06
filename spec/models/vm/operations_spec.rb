RSpec.describe 'VM::Operations' do
  before do
    @miq_server = EvmSpecHelper.local_miq_server
    @ems        = FactoryBot.create(:ems_vmware, :zone => @miq_server.zone)
    @vm         = FactoryBot.create(:vm_vmware, :ems_id => @ems.id)
    ipaddresses = %w(fe80::21a:4aff:fe22:dde5 127.0.0.1)
    allow(@vm).to receive(:ipaddresses).and_return(ipaddresses)

    @hardware = FactoryBot.create(:hardware)
    @hardware.ipaddresses << '10.142.0.2'
    @hardware.ipaddresses << '35.190.140.48'
  end

  context '#cockpit_url' do
    it '#returns a valid Cockpit url' do
      url = @vm.send(:cockpit_url)
      expect(url).to eq(URI::HTTP.build(:host => "127.0.0.1", :port => 9090))
    end
  end

  context '#ipv4_address' do
    it 'returns the existing ipv4 address' do
      url = @vm.send(:ipv4_address)
      expect(url).to eq('127.0.0.1')
    end

    context 'cloud providers' do
      before { @ipaddresses = %w(10.10.1.121 35.190.140.48) }
      it 'returns the public ipv4 address for AWS' do
        ems = FactoryBot.create(:ems_google, :project => 'manageiq-dev')
        az  = FactoryBot.create(:availability_zone_google)
        vm = FactoryBot.create(:vm_google,
                                :ext_management_system => ems,
                                :ems_ref               => 123,
                                :availability_zone     => az,
                                :hardware              => @hardware)
        allow(vm).to receive(:ipaddresses).and_return(@ipaddresses)
        url = vm.send(:ipv4_address)
        expect(url).to eq('35.190.140.48')
      end

      it 'returns the public ipv4 address for GCE' do
        ems = FactoryBot.create(:ems_amazon)
        vm = FactoryBot.create(:vm_amazon, :ext_management_system => ems, :hardware => @hardware)
        allow(vm).to receive(:ipaddresses).and_return(@ipaddresses)
        url = vm.send(:ipv4_address)
        expect(url).to eq('35.190.140.48')
      end
    end
  end

  context '#public_address' do
    it 'returns a public ipv4 address' do
      ipaddresses = %w(10.10.1.121 35.190.140.48)
      ems = FactoryBot.create(:ems_amazon)
      vm = FactoryBot.create(:vm_amazon, :ext_management_system => ems, :hardware => @hardware)
      allow(vm).to receive(:ipaddresses).and_return(ipaddresses)
      url = vm.send(:public_address)
      expect(url).to eq('35.190.140.48')
    end
  end

  describe '#supports_vmrc_console?' do
    it 'returns false if type is not supported' do
      allow(@vm).to receive(:console_supported?).with('VMRC').and_return(false)

      expect(@vm.supports_vmrc_console?).to be_falsey
      expect(@vm.unsupported_reason(:vmrc_console)).to include('VMRC Console not supported')
    end

    it 'supports it if all conditions are met' do
      allow(@vm).to receive(:console_supported?).with('VMRC').and_return(true)

      expect(@vm.supports_vmrc_console?).to be_truthy
    end
  end

  describe '#supports_html5_console?' do
    it 'supports it if all conditions are met' do
      allow(@vm).to receive(:console_supported?).and_return(true)
      expect(@vm.supports_html5_console?).to be_truthy
    end

    it 'returns false if type is not supported' do
      allow(@vm).to receive(:console_supported?).and_return(false)
      expect(@vm.supports_html5_console?).to be_falsey
      expect(@vm.unsupported_reason(:html5_console)).to include('HTML5 Console is not supported')
    end
  end

  describe '#supports_native_console?' do
    it 'returns false if type is not supported' do
      allow(@vm).to receive(:console_supported?).with('NATIVE').and_return(false)

      expect(@vm.supports_native_console?).to be_falsey
      expect(@vm.unsupported_reason(:native_console)).to include('NATIVE Console not supported')
    end

    it 'supports it if all conditions are met' do
      allow(@vm).to receive(:console_supported?).with('NATIVE').and_return(true)

      expect(@vm.supports_native_console?).to be_truthy
    end
  end

  describe '#supports_launch_vmrc_console?' do
    it 'does not support it if validate_remote_console_vmrc_support raises an error' do
      allow(@vm).to receive(:validate_remote_console_vmrc_support).and_raise(StandardError)

      expect(@vm.supports_launch_vmrc_console?).to be_falsey
      expect(@vm.unsupported_reason(:launch_vmrc_console)).to include('VM VMRC Console error:')
    end

    it 'supports it if all conditions are met' do
      allow(@vm).to receive(:validate_remote_console_vmrc_support).and_return(true)

      expect(@vm.supports_launch_vmrc_console?).to be_truthy
    end
  end

  describe '#supports_launch_html5_console?' do
    it 'does not support it if vm is not powered on' do
      allow(@vm).to receive(:power_state).and_return('off')

      expect(@vm.supports_launch_html5_console?).to be_falsey
      expect(@vm.unsupported_reason(:launch_html5_console)).to include('the VM is not powered on')
    end

    it 'supports it if all conditions are met' do
      allow(@vm).to receive(:power_state).and_return('on')

      expect(@vm.supports_launch_html5_console?).to be_truthy
    end
  end

  describe '#supports_launch_native_console?' do
    it 'does not support it if validate_native_console_support raises an error' do
      allow(@vm).to receive(:validate_native_console_support).and_raise(StandardError)

      expect(@vm.supports_launch_native_console?).to be_falsey
      expect(@vm.unsupported_reason(:launch_native_console)).to include('VM NATIVE Console error:')
    end

    it 'supports it if all conditions are met' do
      allow(@vm).to receive(:validate_native_console_support)

      expect(@vm.supports_launch_native_console?).to be_truthy
    end
  end
end
