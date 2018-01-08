describe CockpitSupportMixin do
  context '#supports_launch_cockpit?' do
    context 'Container Groups' do
      before do
        @container_group = FactoryGirl.create(:container_group)
      end

      it 'does not support it if the ready condition is not true' do
        allow(@container_group).to receive(:ready_condition_status).and_return('False')
        allow(@container_group).to receive(:ipaddress).and_return('000.0.0.0')

        expect(@container_group.supports_launch_cockpit?).to be_falsey
        expect(@container_group.unsupported_reason(:launch_cockpit)).to include('Container Node is not powered on')
      end

      it 'does not support it if there is no ip address' do
        allow(@container_group).to receive(:ready_condition_status).and_return('True')

        expect(@container_group.supports_launch_cockpit?).to be_falsey
        expect(@container_group.unsupported_reason(:launch_cockpit)).to include('requires an IP address')
      end

      it 'supports it if all conditions are met' do
        allow(@container_group).to receive(:ready_condition_status).and_return('True')
        allow(@container_group).to receive(:ipaddress).and_return('000.0.0.0')

        expect(@container_group.supports_launch_cockpit?).to be_truthy
      end
    end

    context 'VMs' do
      before do
        @vm = FactoryGirl.create(:vm)
      end

      it 'does not support it if there are no ipaddresses present' do
        allow(@vm).to receive(:power_state).and_return('on')
        allow(@vm).to receive(:ipaddresses).and_return([])

        expect(@vm.supports_launch_cockpit?).to be_falsey
        expect(@vm.unsupported_reason(:launch_cockpit)).to include('requires an IP address')
      end

      it 'does not support it if the vm is not powered on' do
        allow(@vm).to receive(:ipaddresses).and_return(['000.0.0.0'])
        allow(@vm).to receive(:power_state).and_return('off')

        expect(@vm.supports_launch_cockpit?).to be_falsey
        expect(@vm.unsupported_reason(:launch_cockpit)).to include('not available because the VM is not powered on')
      end

      it 'supports it if all conditions are met' do
        allow(@vm).to receive(:ipaddresses).and_return(['000.0.0.0'])
        allow(@vm).to receive(:power_state).and_return('on')

        expect(@vm.supports_launch_cockpit?).to be_truthy
      end
    end
  end

  context '#supports_cockpit_console?' do
    context 'VMs' do
      before do
        @vm = FactoryGirl.create(:vm)
      end

      it 'is not supported for windows platforms' do
        allow(@vm).to receive(:platform).and_return('windows')

        expect(@vm.supports_cockpit_console?).to be_falsey
        expect(@vm.unsupported_reason(:cockpit_console)).to include('Windows platform is not supported')
      end

      it 'supports it if all conditions are met' do
        allow(@vm).to receive(:platform).and_return('vmware')

        expect(@vm.supports_cockpit_console?).to be_truthy
      end
    end
  end
end
