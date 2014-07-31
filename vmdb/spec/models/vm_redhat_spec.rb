require "spec_helper"

describe VmRedhat do
  context "#is_available?" do
    let (:ems)  { FactoryGirl.create(:ems_redhat) }
    let (:host) { FactoryGirl.create(:host_redhat, :ext_management_system => ems) }
    let (:vm)   { FactoryGirl.create(:vm_vmware, :ext_management_system => ems, :host => host) }

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

  context "#cloneable?" do
    let(:vm_redhat) { VmRedhat.new }

    it "returns true" do
      expect(vm_redhat.cloneable?).to eq(true)
    end
  end
end
