require "spec_helper"

describe ManageIQ::Providers::Vmware::InfraManager::Vm do
  context "#is_available?" do
    let(:ems)  { FactoryGirl.create(:ems_vmware) }
    let(:host) { FactoryGirl.create(:host_vmware_esx, :ext_management_system => ems) }
    let(:vm)   { FactoryGirl.create(:vm_vmware, :ext_management_system => ems, :host => host) }
    let(:power_state_on)        { "poweredOn" }
    let(:power_state_suspended) { "poweredOff" }

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
    let(:vm_vmware) { ManageIQ::Providers::Vmware::InfraManager::Vm.new }

    it "returns true" do
      expect(vm_vmware.cloneable?).to eq(true)
    end
  end

  describe "Reconfigure Task" do
    let(:vm) { vm = FactoryGirl.create(:vm_vmware, :hardware => FactoryGirl.create(:hardware, :virtual_hw_version => "07")) }

    it "#reconfigurable?" do
      expect(vm.reconfigurable?).to be_true
    end

    context "#max_total_vcpus" do
      before do
        @host = FactoryGirl.create(:host, :hardware => FactoryGirl.create(:hardware, :cpu_total_cores => 160))
        vm.host = @host
      end
      subject { vm.max_total_vcpus }

      context "vitural_hw_version" do
        it "07" do
          expect(subject).to eq(8)
        end

        it "08" do
          vm.hardware.update_attributes(:virtual_hw_version => "08")
          expect(subject).to eq(32)
        end

        it "09" do
          vm.hardware.update_attributes(:virtual_hw_version => "09")
          expect(subject).to eq(64)
        end

        it "10" do
          vm.hardware.update_attributes(:virtual_hw_version => "10")
          expect(subject).to eq(64)
        end
      end

      it "small host logical cpus" do
        @host.hardware.update_attributes(:cpu_total_cores => 4)
        expect(subject).to eq(4)
      end

      it "big host logical cpus" do
        expect(subject).to eq(8)
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

      ems.invoke_vim_ws(:do_nothing, vm).should eq("nada")
    end
  end
end
