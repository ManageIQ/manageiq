describe ManageIQ::Providers::Vmware::InfraManager::Vm do
  let(:ems)  { FactoryGirl.create(:ems_vmware) }
  let(:host) { FactoryGirl.create(:host_vmware_esx, :ext_management_system => ems) }
  let(:vm)   { FactoryGirl.create(:vm_vmware, :ext_management_system => ems, :host => host) }
  let(:power_state_on)        { "poweredOn" }
  let(:power_state_suspended) { "poweredOff" }

  context "#is_available?" do
    context("with :start") do
      let(:state) { :start }
      include_examples "Vm operation is available when not powered on"
    end

    context("with :stop") do
      let(:state) { :stop }
      include_examples "Vm operation is available when powered on"
    end

    context("with :suspend") do
      let(:state) { :suspend }
      include_examples "Vm operation is available when powered on"
    end

    context("with :standby_guest") do
      let(:state) { :standby_guest }
      include_examples "Vm operation is available when powered on"
    end

    context("with :reboot_guest") do
      let(:state) { :reboot_guest }
      include_examples "Vm operation is available when powered on"
    end

    context("with :reset") do
      let(:state) { :reset }
      include_examples "Vm operation is available when powered on"
    end
  end

  context "supports_clone?" do
    it "returns true" do
      expect(vm.supports?(:clone)).to eq(true)
    end
  end

  context "supports_shutdown_guest?" do
    let(:op) { 'shutdown_guest' }

    context "when powered off" do
      let(:vm_status) { {:raw_power_state => power_state_suspended} }

      it 'is not available if tools is not installed' do
        vm_status[:tools_status] = 'toolsNotInstalled'
        vm.update_attributes(vm_status)
        expect(vm.public_send("supports_#{op}?")).to be false
        expect(vm.unsupported_reason(op)).to include("power")
      end

      it 'is not available even if tools is installed' do
        vm_status[:tools_status] = nil
        vm.update_attributes(vm_status)
        expect(vm.public_send("supports_#{op}?")).to be false
        expect(vm.unsupported_reason(op)).to include("power")
      end
    end

    context "when powered on" do
      let(:vm_status) { {:raw_power_state => power_state_on} }

      it 'is not available if tools not installed' do
        vm_status[:tools_status] = 'toolsNotInstalled'
        vm.update_attributes(vm_status)
        expect(vm.public_send("supports_#{op}?")).to be false
        expect(vm.unsupported_reason(op)).to include("tools")
      end

      it 'is available if tools installed' do
        vm_status[:tools_status] = nil
        expect(vm.public_send("supports_#{op}?")).to be true
      end
    end
  end

  context "vim" do
    let(:ems) { FactoryGirl.create(:ems_vmware) }
    let(:provider_object) do
      double("vm_vmware_provider_object", :destroy => nil).as_null_object
    end
    let(:vm)  { FactoryGirl.create(:vm_vmware, :ext_management_system => ems) }

    it "#invoke_vim_ws" do
      expect(vm).to receive(:with_provider_object).and_yield(provider_object)
      expect(provider_object).to receive(:send).and_return("nada")

      expect(ems.invoke_vim_ws(:do_nothing, vm)).to eq("nada")
    end
  end
end
