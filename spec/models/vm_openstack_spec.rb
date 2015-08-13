require "spec_helper"

describe ManageIQ::Providers::Openstack::CloudManager::Vm do
  context "#is_available?" do
    let(:ems) { FactoryGirl.create(:ems_openstack) }
    let(:vm)  { FactoryGirl.create(:vm_openstack, :ext_management_system => ems) }
    let(:power_state_on)        { "ACTIVE" }
    let(:power_state_suspended) { "SUSPENDED" }

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
      include_examples "Vm operation is available when powered on"
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
      include_examples "Vm operation is available when powered on"
    end
  end

  context "when detroyed" do
    let(:ems) { FactoryGirl.create(:ems_openstack) }
    let(:provider_object) do
      double("vm_openstack_provider_object", :destroy => nil).as_null_object
    end
    let(:vm)  { FactoryGirl.create(:vm_openstack, :ext_management_system => ems) }

    it "sets the raw_power_state and not state" do
      expect(vm).to receive(:with_provider_object).and_yield(provider_object)
      vm.raw_destroy
      vm.raw_power_state.should == "DELETED"
      vm.state.should == "archived"
    end
  end
end
