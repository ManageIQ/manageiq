describe 'Vm::Operations' do
  before do
    @ems = FactoryGirl.create(:ems_vmware)
    @vm = FactoryGirl.create(:vm_vmware, :ems_id => @ems.id)
  end

  context '#supports_vnc_console?' do
    it 'does not support it for vmware vms if it is not the specified console type in settings' do
      allow(@vm).to receive(:vendor).and_return('vmware')
      allow(@vm).to receive(:console_supports_type?).with('VNC').and_return(false)

      expect(@vm.supports_vnc_console?).to be_falsey
      expect(@vm.unsupported_reason(:vnc_console)).to include('VNC Console not supported')
    end

    it 'adds unsupported reason for non-vmware vms and unsupported types' do
      allow(@vm).to receive(:vendor).and_return('amazon')
      allow(@vm).to receive(:console_supported?).with('VNC').and_return(false)

      expect(@vm.supports_vnc_console?).to be_falsey
      expect(@vm.unsupported_reason(:vnc_console)).to include('VNC Console not supported')
    end

    it 'supports it if all conditions are met' do
      server = double
      allow(Settings).to receive(:server).and_return(server)
      allow(server).to receive(:remote_console_type).and_return('VNC')

      expect(@vm.supports_vnc_console?).to be_truthy
    end
  end

  context '#supports_mks_console?' do
    it 'is not supported if the console type is not supported' do
      allow(@vm).to receive(:power_state).and_return('on')

      expect(@vm.supports_mks_console?).to be_falsey
      expect(@vm.unsupported_reason(:mks_console)).to include('WebMKS Console not supported')
    end

    it 'supports it if all conditions are met' do
      allow(@vm).to receive(:console_supported?).with('WEBMKS').and_return(true)
      allow(@vm).to receive(:console_supports_type?).with('WebMKS').and_return(true)

      expect(@vm.supports_mks_console?).to be_truthy
    end
  end

  context '#supports_launch_vnc_console?' do
    before do
      @ems_double = double
      allow(@vm).to receive(:ext_management_system).and_return(@ems_double)
    end

    it 'does not support if vendor is vmware and api version is >= 6.5' do
      allow(@ems_double).to receive(:api_version).and_return('6.5')
      allow(@vm).to receive(:vendor).and_return('vmware')

      expect(@vm.supports_launch_vnc_console?).to be_falsey
      expect(@vm.unsupported_reason(:launch_vnc_console)).to include('unsupported on VMware ESXi 6.5 and later')
    end

    it 'does not support if vm is not powered on' do
      allow(@ems_double).to receive(:api_version).and_return('6.4')
      allow(@vm).to receive(:power_state).and_return('off')

      expect(@vm.supports_launch_vnc_console?).to be_falsey
      expect(@vm.unsupported_reason(:launch_vnc_console)).to include('the VM is not powered on')
    end

    it 'supports it if all conditions are met' do
      allow(@vm).to receive(:power_state).and_return('on')
      allow(@vm).to receive(:vendor).and_return('vmware')
      allow(@ems_double).to receive(:api_version).and_return('6.4')

      expect(@vm.supports_launch_vnc_console?).to be_truthy
    end
  end

  context '#supports_launch_mks_console?' do
    before do
      root, @join = double, double
      allow(Rails).to receive(:root).and_return(root)
      allow(root).to receive(:join).with('public', 'webmks').and_return(@join)
    end

    it 'is not supported if the vm is not powered on' do
      allow(@vm).to receive(:power_state).and_return('off')

      expect(@vm.supports_launch_mks_console?).to be_falsey
      expect(@vm.unsupported_reason(:launch_mks_console)).to include('the VM is not powered on')
    end

    it 'is not supported if the required libraries are not installed' do
      allow(@join).to receive(:exist?).and_return(false)
      allow(@vm).to receive(:power_state).and_return('on')

      expect(@vm.supports_launch_mks_console?).to be_falsey
      expect(@vm.unsupported_reason(:launch_mks_console)).to include("the required libraries aren't installed")
    end

    it 'supports it if all conditions are met' do
      allow(@join).to receive(:exist?).and_return(true)
      allow(@vm).to receive(:power_state).and_return('on')

      expect(@vm.supports_launch_mks_console?).to be_truthy
    end
  end

  context '#supports_vmrc_console?' do
    it 'returns false if type is not supported' do
      allow(@vm).to receive(:console_supports_type?).with('VMRC').and_return(false)

      expect(@vm.supports_vmrc_console?).to be_falsey
      expect(@vm.unsupported_reason(:vmrc_console)).to include('VMRC Console not supported')
    end

    it 'supports it if all conditions are met' do
      allow(@vm).to receive(:console_supports_type?).with('VMRC').and_return(true)

      expect(@vm.supports_vmrc_console?).to be_truthy
    end
  end

  context '#supports_spice_console?' do
    it 'returns false if type is not supported' do
      allow(@vm).to receive(:console_supports_type?).with('SPICE').and_return(false)

      expect(@vm.supports_spice_console?).to be_falsey
      expect(@vm.unsupported_reason(:spice_console)).to include('Spice Console not supported')
    end

    it 'supports it if all conditions are met' do
      allow(@vm).to receive(:console_supports_type?).with('SPICE').and_return(true)

      expect(@vm.supports_spice_console?).to be_truthy
    end
  end

  context '#supports_launch_cockpit?' do
    it 'does not support it if there are no ipaddresses present' do
      allow(@vm).to receive(:ipaddresses).and_return([])

      expect(@vm.supports_launch_cockpit?).to be_falsey
      expect(@vm.unsupported_reason(:launch_cockpit)).to include('requires an IP address')
    end

    it 'supports it if all conditions are met' do
      allow(@vm).to receive(:ipaddresses).and_return(['000.0.0.0'])

      expect(@vm.supports_launch_cockpit?).to be_truthy
    end
  end

  context '#supports_launch_vmrc_console?' do
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

  context '#supports_launch_spice_console?' do
    it 'does not support it if vm is not powered on' do
      allow(@vm).to receive(:power_state).and_return('off')

      expect(@vm.supports_launch_spice_console?).to be_falsey
      expect(@vm.unsupported_reason(:launch_spice_console)).to include('the VM is not powered on')
    end

    it 'supports it if all conditions are met' do
      allow(@vm).to receive(:power_state).and_return('on')

      expect(@vm.supports_launch_spice_console?).to be_truthy
    end
  end
end
