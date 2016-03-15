describe ManageIQ::Providers::Amazon::CloudManager::Vm do
  context "#is_available?" do
    let(:ems)                   { FactoryGirl.create(:ems_amazon) }
    let(:vm)                    { FactoryGirl.create(:vm_amazon, :ext_management_system => ems) }
    let(:power_state_on)        { "running" }
    let(:power_state_suspended) { "pending" }

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
      include_examples "Vm operation is not available"
    end

    context("with :pause") do
      let(:state) { :pause }
      include_examples "Vm operation is not available"
    end

    context("with :shutdown_guest") do
      let(:state) { :shutdown_guest }
      include_examples "Vm operation is not available"
    end

    context("with :standby_guest") do
      let(:state) { :standby_guest }
      include_examples "Vm operation is not available"
    end

    context("with :reboot_guest") do
      let(:state) { :reboot_guest }
      include_examples "Vm operation is available when powered on"
    end

    context("with :reset") do
      let(:state) { :reset }
      include_examples "Vm operation is not available"
    end
  end
end
