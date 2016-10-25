describe ManageIQ::Providers::Redhat::InfraManager::Vm do
  context "#is_available?" do
    let(:ems)  { FactoryGirl.create(:ems_redhat) }
    let(:host) { FactoryGirl.create(:host_redhat, :ext_management_system => ems) }
    let(:vm)   { FactoryGirl.create(:vm_redhat, :ext_management_system => ems, :host => host) }
    let(:power_state_on)        { "up" }
    let(:power_state_suspended) { "down" }

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

    context("with :pause") do
      let(:state) { :pause }
      include_examples "Vm operation is not available"
    end

    context("with :shutdown_guest") do
      let(:state) { :shutdown_guest }
      include_examples "Vm operation is available when powered on"
    end

    context("with :standby_guest") do
      let(:state) { :standby_guest }
      include_examples "Vm operation is not available"
    end

    context("with :reboot_guest") do
      let(:state) { :reboot_guest }
      include_examples "Vm operation is not available"
    end

    context("with :reset") do
      let(:state) { :reset }
      include_examples "Vm operation is not available"
    end
  end

  context "supports_clone?" do
    let(:vm_redhat) { ManageIQ::Providers::Redhat::InfraManager::Vm.new }

    it "returns false" do
      expect(vm_redhat.supports?(:clone)).to eq(false)
    end
  end

  context "#calculate_power_state" do
    it "returns suspended when suspended" do
      expect(described_class.calculate_power_state('suspended')).to eq('suspended')
    end

    it "returns on when up" do
      expect(described_class.calculate_power_state('up')).to eq('on')
    end

    it "returns down when off" do
      expect(described_class.calculate_power_state('down')).to eq('off')
    end
  end
end
