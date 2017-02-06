describe ManageIQ::Providers::Redhat::InfraManager::Vm do
  let(:ip_address) { '192.168.1.31' }

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

  describe "#supports_reconfigure_disks?" do
    context "when vm has no storage" do
      let(:vm) { FactoryGirl.create(:vm_redhat, :storage => nil, :ext_management_system => nil) }

      it "does not support reconfigure disks" do
        expect(vm.supports_reconfigure_disks?).to be_falsey
      end
    end

    context "when vm has storage" do
      let(:storage) { FactoryGirl.create(:storage_nfs, :ems_ref => "http://example.com/storages/XYZ") }
      let(:vm) { FactoryGirl.create(:vm_redhat, :storage => storage, :ext_management_system => nil) }

      context "when vm has no provider" do
        it "does not support reconfigure disks" do
          expect(vm.supports_reconfigure_disks?).to be_falsey
        end
      end

      context "when vm has provider" do
        let(:ems_redhat) { FactoryGirl.create(:ems_redhat) }
        let(:supported_api_versions) { [3] }
        let(:vm) { FactoryGirl.create(:vm_redhat, :storage => storage) }

        before(:each) do
          allow(vm.ext_management_system).to receive(:supported_api_versions).and_return(supported_api_versions)

          context "when provider does not support reconfigure disks" do
            it "does not support reconfigure disks" do
              expect(vm.supports_reconfigure_disks?).to be_falsey
            end
          end

          context "when provider supports reconfigure disks" do
            let(:supported_api_versions) { [3] }
            it "supports reconfigure disks" do
              expect(vm.supports_reconfigure_disks?).to be_truthy
            end
          end
        end
      end
    end
  end

  describe "#disconnect_storage" do
    before(:each) do
      _, _, zone = EvmSpecHelper.create_guid_miq_server_zone
      ems = FactoryGirl.create(:ems_redhat, :zone => zone, :hostname => ip_address,
                               :ipaddress => ip_address, :port => 8443)
      ems.update_authentication(:default => {:userid => "admin@internal", :password => "engine"})
      allow(ems).to receive(:supported_api_versions).and_return([3, 4])
      allow(ems).to receive(:resolve_ip_address).with(ip_address).and_return(ip_address)

      @storage = FactoryGirl.create(:storage, :ems_ref => "/api/storagedomains/ee745353-c069-4de8-8d76-ec2e155e2ca0")
      disk = FactoryGirl.create(:disk, :storage => @storage, :filename => "da123bb9-095a-4933-95f2-8032dfa332e1")
      hardware = FactoryGirl.create(:hardware, :disks => [disk])
      @vm = FactoryGirl.create(:vm_redhat, :storage => @storage, :storages => [@storage], :hardware => hardware, :ext_management_system => ems)
    end

    context "vm removed and" do
      it "disks removed" do
        VCR.use_cassette("#{described_class.name.underscore}_fetch_no_disks") do
          @vm.disconnect_storage
        end

        expect(@vm.storage).to be_nil
        expect(@vm.storages).to be_empty
      end

      it "disks not removed" do
        VCR.use_cassette("#{described_class.name.underscore}_fetch_disks") do
          @vm.disconnect_storage
        end

        expect(@vm.storage).to eq(@storage)
      end
    end
  end
end
