describe ManageIQ::Providers::Openstack::CloudManager::Vm do
  describe "vm actions" do
    let(:ems) { FactoryGirl.create(:ems_openstack) }
    let(:tenant) { FactoryGirl.create(:cloud_tenant_openstack, :ext_management_system => ems) }
    let(:vm) do
      FactoryGirl.create(:vm_openstack,
                         :ext_management_system => ems,
                         :name                  => 'test',
                         :ems_ref               => 'one_id',
                         :cloud_tenant          => tenant)
    end

    let(:handle) do
      double.tap do |handle|
        allow(ems).to receive(:connect).with({}).and_return(handle)
      end
    end

    before do
      handle
    end

    context "#live_migrate" do
      it "live migrates with default options" do
        expect(handle).to receive(:live_migrate_server).with(vm.ems_ref, nil, false, false)
        vm.live_migrate
        expect(vm.power_state).to eq 'migrating'
      end

      it "live migrates with special options" do
        expect(handle).to receive(:live_migrate_server).with(vm.ems_ref, 'host_1.localdomain', true, true)
        vm.live_migrate(:hostname => 'host_1.localdomain', :disk_over_commit => true, :block_migration => true)
        expect(vm.power_state).to eq 'migrating'
      end

      it "checks live migration is_available?" do
        expect(vm.is_available?(:live_migrate)).to eq true
      end
    end

    context "evacuate" do
      it "evacuates with default options" do
        expect(handle).to receive(:evacuate_server).with(vm.ems_ref, nil, true, nil)
        vm.evacuate
        expect(vm.power_state).to eq 'migrating'
      end

      it "evacuates with special options" do
        expect(handle).to receive(:evacuate_server).with(vm.ems_ref, 'host_1.localdomain', false, 'blah')
        vm.evacuate(:hostname => 'host_1.localdomain', :on_shared_storage => false, :admin_password => 'blah')
        expect(vm.power_state).to eq 'migrating'
      end

      it "evacuates with special options" do
        expect(handle).to receive(:evacuate_server).with(vm.ems_ref, 'host_1.localdomain', true, nil)
        vm.evacuate(:hostname => 'host_1.localdomain', :on_shared_storage => true)
        expect(vm.power_state).to eq 'migrating'
      end

      it "checks evacuation is_available?" do
        expect(vm.is_available?(:evacuate)).to eq true
      end
    end
  end

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
      expect(vm.raw_power_state).to eq("DELETED")
      expect(vm.state).to eq("archived")
    end
  end

  context "when resized" do
    let(:ems) { FactoryGirl.create(:ems_openstack) }
    let(:cloud_tenant) { FactoryGirl.create(:cloud_tenant) }
    let(:vm) { FactoryGirl.create(:vm_openstack, :ext_management_system => ems, :cloud_tenant => cloud_tenant) }
    let(:flavor) { FactoryGirl.create(:flavor_openstack, :ems_ref => '2') }

    it "initiate resize process" do
      service = double
      allow(ems).to receive(:connect).and_return(service)
      expect(vm.validate_resize).to be true
      expect(vm.validate_resize_confirm).to be false
      expect(service).to receive(:resize_server).with(vm.ems_ref, flavor.ems_ref)
      vm.resize(flavor)
    end

    it 'confirm resize' do
      vm.raw_power_state = 'VERIFY_RESIZE'
      service = double
      allow(ems).to receive(:connect).and_return(service)
      expect(vm.validate_resize).to be false
      expect(vm.validate_resize_confirm).to be true
      expect(service).to receive(:confirm_resize_server).with(vm.ems_ref)
      vm.resize_confirm
    end

    it 'revert resize' do
      vm.raw_power_state = 'VERIFY_RESIZE'
      service = double
      allow(ems).to receive(:connect).and_return(service)
      expect(vm.validate_resize).to be false
      expect(vm.validate_resize_revert).to be true
      expect(service).to receive(:revert_resize_server).with(vm.ems_ref)
      vm.resize_revert
    end
  end
end
