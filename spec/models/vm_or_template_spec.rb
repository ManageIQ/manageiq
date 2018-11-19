describe VmOrTemplate do
  include Spec::Support::ArelHelper

  let(:vm)      { FactoryGirl.create(:vm_or_template) }
  let(:ems)     { FactoryGirl.create(:ext_management_system) }
  let(:storage) { FactoryGirl.create(:storage) }

  # Basically these specs are a truth table for the #registered? method, but
  # need it to verify functionality when converting these to scopes
  describe "being registered" do
    subject                { FactoryGirl.create(:vm_or_template, attrs) }
    let(:host)             { FactoryGirl.create(:host) }
    let(:registered_vms)   { described_class.registered.to_a }
    let(:unregistered_vms) { described_class.unregistered.to_a }

    # Preloads subject so that the registered_vms and unregistered_vms specs
    # have it available to query against.
    before { subject }

    context "with attrs of template => false, ems_id => nil, host_id => nil" do
      let(:attrs) { { :template => false, :ems_id => nil, :host_id => nil } }

      it("is not #registered?")        { expect(subject.registered?).to be false }
      it("is not in registered_vms")   { expect(registered_vms).to_not include subject }
      it("is in unregistered_vms")     { expect(unregistered_vms).to include subject }
    end

    context "with attrs template => false, ems_id => nil, host_id => [ID]" do
      let(:attrs) { { :template => false, :ems_id => nil, :host_id => host.id } }

      it("is #registered?")            { expect(subject.registered?).to be true }
      it("is in registered_vms")       { expect(registered_vms).to include subject }
      it("is not in unregistered_vms") { expect(unregistered_vms).to_not include subject }
    end

    context "with attrs template => false, ems_id => [ID], host_id => nil" do
      let(:attrs) { { :template => false, :ems_id => ems.id, :host_id => nil } }

      it("is not #registered?")        { expect(subject.registered?).to be false }
      it("is not in registered_vms")   { expect(registered_vms).to_not include subject }
      it("is in unregistered_vms")     { expect(unregistered_vms).to include subject }
    end

    context "with attrs template => false, ems_id => [ID], host_id => [ID]" do
      let(:attrs) { { :template => false, :ems_id => ems.id, :host_id => host.id } }

      it("is #registered?")            { expect(subject.registered?).to be true }
      it("is in registered_vms")       { expect(registered_vms).to include subject }
      it("is not in unregistered_vms") { expect(unregistered_vms).to_not include subject }
    end

    context "with attrs template => true, ems_id => nil, host_id => nil" do
      let(:attrs) { { :template => true, :ems_id => nil, :host_id => nil } }

      it("is not #registered?")        { expect(subject.registered?).to be false }
      it("is not in registered_vms")   { expect(registered_vms).to_not include subject }
      it("is in unregistered_vms")     { expect(unregistered_vms).to include subject }
    end

    context "with attrs if template => true, ems_id => nil, host_id => [ID]" do
      let(:attrs) { { :template => true, :ems_id => nil, :host_id => host.id } }

      it("is not #registered?")        { expect(subject.registered?).to be false }
      it("is not in registered_vms")   { expect(registered_vms).to_not include subject }
      it("is in unregistered_vms")     { expect(unregistered_vms).to include subject }
    end

    context "with attrs if template => true, ems_id => [ID], host_id => nil" do
      let(:attrs) { { :template => true, :ems_id => ems.id, :host_id => nil } }

      it("is not #registered?")        { expect(subject.registered?).to be false }
      it("is not in registered_vms")   { expect(registered_vms).to_not include subject }
      it("is in unregistered_vms")     { expect(unregistered_vms).to include subject }
    end

    context "with attrs if template => true, ems_id => [ID], host_id => [ID]" do
      let(:attrs) { { :template => true, :ems_id => ems.id, :host_id => host.id } }

      it("is #registered?")            { expect(subject.registered?).to be true }
      it("is in registered_vms")       { expect(registered_vms).to include subject }
      it("is not in unregistered_vms") { expect(unregistered_vms).to_not include subject }
    end
  end

  describe ".miq_expression_includes_any_ipaddresses_arel" do
    subject              { FactoryGirl.create(:vm) }
    let(:no_hardware_vm) { FactoryGirl.create(:vm) }
    let(:wrong_ip_vm)    { FactoryGirl.create(:vm) }

    before do
      hw1 = FactoryGirl.create(:hardware, :vm => subject)
      FactoryGirl.create(:network, :hardware => hw1, :ipaddress => "10.11.11.11")
      FactoryGirl.create(:network, :hardware => hw1, :ipaddress => "10.10.10.10")
      FactoryGirl.create(:network, :hardware => hw1, :ipaddress => "10.10.10.11")

      hw2 = FactoryGirl.create(:hardware, :vm => wrong_ip_vm)
      FactoryGirl.create(:network, :hardware => hw2, :ipaddress => "11.11.11.11")
    end

    it "runs a single query, returning only the valid vm" do
      expect do
        query  = Vm.miq_expression_includes_any_ipaddresses_arel("10.10.10")
        result = Vm.where(query)
        expect(result.to_a).to eq([subject])
      end.to match_query_limit_of(1)
    end
  end

  context ".event_by_property" do
    context "should add an EMS event" do
      before do
        Timecop.freeze(Time.now)

        @host            = FactoryGirl.create(:host,      :name  => "host")
        @vm              = FactoryGirl.create(:vm_vmware, :host  => @host, :name => "vm", :uid_ems => "1", :ems_id => 101)

        @event_type      = "foo"
        @event_timestamp = Time.now.utc
      end

      after do
        Timecop.return
      end

      it "by IP Address" do
        ipaddress       = "192.268.20.1"
        hardware        = FactoryGirl.create(:hardware,  :vm_or_template_id => @vm.id,       :host     => @host)
        FactoryGirl.create(:network,   :hardware_id       => hardware.id, :ipaddress => ipaddress)
        event_msg       = "Add EMS Event by IP address"

        expect_any_instance_of(VmOrTemplate).to receive(:add_ems_event).with(@event_type, event_msg, @event_timestamp)
        VmOrTemplate.event_by_property("ipaddress", ipaddress, @event_type, event_msg)
      end

      it "by UID EMS" do
        event_msg = "Add EMS Event by UID EMS"

        expect_any_instance_of(VmOrTemplate).to receive(:add_ems_event).with(@event_type, event_msg, @event_timestamp)
        VmOrTemplate.event_by_property("uid_ems", "1", @event_type, event_msg)
      end
    end

    it "should raise an error" do
      err = "Unsupported property type [foo]"
      expect { VmOrTemplate.event_by_property('foo', '', '', '') }.to raise_error(err)
    end
  end

  context "#add_ems_event" do
    before do
      @host            = FactoryGirl.create(:host, :name => "host 1")
      @vm              = FactoryGirl.create(:vm_vmware, :name => "vm 1", :location => "/local/path", :host => @host, :uid_ems => "1", :ems_id => 101)
      @event_type      = "foo"
      @source          = "EVM"
      @event_timestamp = Time.now.utc.iso8601
      @event_hash = {
        :event_type => @event_type,
        :is_task    => false,
        :source     => @source,
        :timestamp  => @event_timestamp,
      }
    end

    context "should add an EMS Event" do
      before do
        @ipaddress       = "192.268.20.1"
        @hardware        = FactoryGirl.create(:hardware, :vm_or_template_id => @vm.id)
        @network         = FactoryGirl.create(:network,  :hardware_id       => @hardware.id, :ipaddress => @ipaddress)
      end

      it "with host and ems id" do
        event_msg = "by IP address"
        @event_hash[:message]           = event_msg
        @event_hash[:vm_or_template_id] = @vm.id
        @event_hash[:vm_name]           = @vm.name
        @event_hash[:vm_location]       = @vm.location
        @event_hash[:host_id]           = @vm.host_id
        @event_hash[:host_name]         = @host.name
        @event_hash[:ems_id]            = @vm.ems_id

        expect(EmsEvent).to receive(:add).with(@vm.ems_id, @event_hash)
        @vm.add_ems_event(@event_type, event_msg, @event_timestamp)
      end

      it "with no host" do
        vm_no_host       = FactoryGirl.create(:vm_vmware, :name => "vm 2", :location => "/local/path", :uid_ems => "2", :ems_id => 102)
        ipaddress        = "192.268.20.2"
        hardware_no_host = FactoryGirl.create(:hardware, :vm_or_template_id => vm_no_host.id)
        FactoryGirl.create(:network,  :hardware_id       => hardware_no_host.id, :ipaddress => ipaddress)

        event_msg = "Add EMS Event by IP address with no host"
        @event_hash[:message]           = event_msg
        @event_hash[:vm_or_template_id] = vm_no_host.id
        @event_hash[:vm_name]           = vm_no_host.name
        @event_hash[:vm_location]       = vm_no_host.location
        @event_hash[:ems_id]            = vm_no_host.ems_id

        expect(EmsEvent).to receive(:add).with(vm_no_host.ems_id, @event_hash)
        vm_no_host.add_ems_event(@event_type, event_msg, @event_timestamp)
      end

      it "with no ems id" do
        vm_no_ems       = FactoryGirl.create(:vm_vmware, :name => "vm 3", :location => "/local/path", :host => @host)
        ipaddress       = "192.268.20.3"
        hardware_no_ems = FactoryGirl.create(:hardware, :vm_or_template_id => vm_no_ems.id)
        FactoryGirl.create(:network,  :hardware_id       => hardware_no_ems.id, :ipaddress => ipaddress)

        event_msg = "Add EMS Event by IP address with no ems id"
        @event_hash[:message]           = event_msg
        @event_hash[:vm_or_template_id] = vm_no_ems.id
        @event_hash[:vm_name]           = vm_no_ems.name
        @event_hash[:vm_location]       = vm_no_ems.location
        @event_hash[:host_id]           = vm_no_ems.host_id
        @event_hash[:host_name]         = @host.name

        expect(EmsEvent).to receive(:add).with(nil, @event_hash)
        vm_no_ems.add_ems_event(@event_type, event_msg, @event_timestamp)
      end

      it "with no host and no ems id" do
        vm_no_host_no_ems       = FactoryGirl.create(:vm_vmware, :name => "vm 4", :location => "/local/path")
        ipaddress               = "192.268.20.4"
        hardware_no_host_no_ems = FactoryGirl.create(:hardware, :vm_or_template_id => vm_no_host_no_ems.id)
        FactoryGirl.create(:network,  :hardware_id       => hardware_no_host_no_ems.id, :ipaddress => ipaddress)

        event_msg = "Add EMS Event by IP address with no host and no ems id"
        @event_hash[:message]           = event_msg
        @event_hash[:vm_or_template_id] = vm_no_host_no_ems.id
        @event_hash[:vm_name]           = vm_no_host_no_ems.name
        @event_hash[:vm_location]       = vm_no_host_no_ems.location

        expect(EmsEvent).to receive(:add).with(nil, @event_hash)
        vm_no_host_no_ems.add_ems_event(@event_type, event_msg, @event_timestamp)
      end
    end
  end

  context "#reconfigured_hardware_value?" do
    before do
      @vm       =  FactoryGirl.create(:vm_vmware)
      FactoryGirl.create(:hardware, :vm_or_template_id => @vm.id, :memory_mb => 1024)
      @options = {:hdw_attr => :memory_mb}
    end

    it "with no drift states" do
      expect(@vm.reconfigured_hardware_value?(@options)).to be_falsey
    end

    context "with a drift state" do
      before { @vm.save_drift_state }

      context "with increased operator" do
        before { @options[:operator] = "increased" }

        it "with the same memory value" do
          @vm.save_drift_state

          expect(@vm.reconfigured_hardware_value?(@options)).to be_falsey
        end

        it "with a lower memory value" do
          @vm.hardware.memory_mb = 512
          @vm.save_drift_state

          expect(@vm.reconfigured_hardware_value?(@options)).to be_falsey
        end

        it "with a higher memory value" do
          @vm.hardware.memory_mb = 2048
          @vm.save_drift_state

          expect(@vm.reconfigured_hardware_value?(@options)).to be_truthy
        end
      end

      context "with decreased operator" do
        before { @options[:operator] = "decreased" }

        it "with the same memory value" do
          @vm.save_drift_state

          expect(@vm.reconfigured_hardware_value?(@options)).to be_falsey
        end

        it "with a lower memory value" do
          @vm.hardware.memory_mb = 512
          @vm.save_drift_state

          expect(@vm.reconfigured_hardware_value?(@options)).to be_truthy
        end

        it "with a higher memory value" do
          @vm.hardware.memory_mb = 2048
          @vm.save_drift_state

          expect(@vm.reconfigured_hardware_value?(@options)).to be_falsey
        end
      end
    end
  end

  context "#miq_server_proxies" do
    context "SmartProxy Affinity" do
      before do
        @storage1 = FactoryGirl.create(:storage)
        @storage2 = FactoryGirl.create(:storage)
        @storage3 = FactoryGirl.create(:storage)

        @host1 = FactoryGirl.create(:host, :name => 'host1', :storages => [@storage1])
        @host2 = FactoryGirl.create(:host, :name => 'host2', :storages => [@storage2])
        @host3 = FactoryGirl.create(:host, :name => 'host3', :storages => [@storage1, @storage2])
        @vm = FactoryGirl.create(:vm_vmware,
                                 :host     => @host1,
                                 :name     => 'vm',
                                 :vendor   => 'vmware',
                                 :storage  => @storage1,
                                 :storages => [@storage1, @storage2])
        @zone = FactoryGirl.create(:zone, :name => 'zone')

        allow_any_instance_of(MiqServer).to receive_messages(:is_vix_disk? => true)
        @svr1 = EvmSpecHelper.local_miq_server(:name => 'svr1')
        @svr2 = FactoryGirl.create(:miq_server, :name => 'svr2', :zone => @svr1.zone)
        @svr3 = FactoryGirl.create(:miq_server, :name => 'svr3', :zone => @svr1.zone)

        @svr1_vm = FactoryGirl.create(:vm_vmware, :host => @host1, :name => 'svr1_vm', :miq_server => @svr1)
        @svr2_vm = FactoryGirl.create(:vm_vmware, :host => @host2, :name => 'svr2_vm', :miq_server => @svr2)
        @svr3_vm = FactoryGirl.create(:vm_vmware, :host => @host3, :name => 'svr3_vm', :miq_server => @svr3)
      end

      it "should select SmartProxies with matching VM host affinity" do
        @svr1.vm_scan_host_affinity = [@host1]
        @svr2.vm_scan_host_affinity = [@host2]
        expect(@vm.miq_server_proxies).to eq([@svr1])
      end

      it "should select SmartProxies without host affinity when the VM host has no affinity" do
        @svr1.vm_scan_host_affinity = [@host2]
        @svr2.vm_scan_host_affinity = [@host2]
        expect(@vm.miq_server_proxies).to eq([@svr3])
      end

      it "should select SmartProxies with matching VM storage affinity" do
        @svr1.vm_scan_storage_affinity = [@storage1, @storage2]
        @svr2.vm_scan_storage_affinity = [@storage2]
        expect(@vm.miq_server_proxies).to eq([@svr1])
      end

      it "should select SmartProxies without storage affinity when the VM storage has no affinity" do
        @svr1.vm_scan_storage_affinity = [@storage3]
        @svr2.vm_scan_storage_affinity = [@storage3]
        expect(@vm.miq_server_proxies).to eq([@svr3])
      end

      it "should not select SmartProxies without matching VM storage affinity for all disks" do
        @svr1.vm_scan_storage_affinity = [@storage1]
        @svr2.vm_scan_storage_affinity = [@storage2]
        expect(@vm.miq_server_proxies).to eq([])
      end

      it "should return empty result when its storage is blank" do
        @vm.storage_id = nil
        @svr1.vm_scan_host_affinity = [@host1]
        @svr2.vm_scan_host_affinity = [@host2]
        expect(@vm.miq_server_proxies).to be_empty
      end
    end

    context "RHEV" do
      before do
        @storage1 = FactoryGirl.create(:storage)
        @storage2 = FactoryGirl.create(:storage)

        @host1 = FactoryGirl.create(:host, :name => 'host1', :storages => [@storage1])
        @host2 = FactoryGirl.create(:host, :name => 'host2', :storages => [@storage2])

        @vm = FactoryGirl.create(:vm_redhat,
                                 :host     => @host1,
                                 :name     => 'vm',
                                 :vendor   => 'redhat',
                                 :storage  => @storage1,
                                 :storages => [@storage1])

        @svr1 = EvmSpecHelper.local_miq_server(:name => 'svr1')
        @svr2 = FactoryGirl.create(:miq_server, :name => 'svr2', :zone => @svr1.zone)

        @svr1_vm = FactoryGirl.create(:vm_redhat, :host => @host1, :name => 'svr1_vm', :miq_server => @svr1)
        @svr1_vm = FactoryGirl.create(:vm_redhat, :host => @host2, :name => 'svr2_vm', :miq_server => @svr2)
      end

      it "should select SmartProxies with access to the same NFS storage" do
        @storage1.store_type = 'NFS'
        expect(Vm).to receive(:miq_servers_for_scan).and_return([@svr1, @svr2])
        expect(@vm.miq_server_proxies).to eq([@svr1])
      end

      it "should select SmartProxies for a powered-off VM" do
        expect(Vm).to receive(:miq_servers_for_scan).and_return([@svr1, @svr2])
        # RHEV VMs do not have an associated host when powered off
        @vm.host = nil
        expect(@vm.miq_server_proxies).to eq([@svr1])
      end
    end
  end

  context "#users" do
    before do
      @vm    = FactoryGirl.create(:vm_vmware)
      @user  = FactoryGirl.create(:account_user,  :vm_or_template => @vm, :name => "test")
      @group = FactoryGirl.create(:account_group, :vm_or_template => @vm, :name => "dev")
    end

    it "association" do
      expect(@vm.users).to     include(@user)
      expect(@vm.users).not_to include(@group)
    end

    it "with includes" do
      expect(Vm.includes(:users, :groups).where(:accounts => {:name => 'test'}).count).to eq(1)
    end
  end

  context "#groups" do
    before do
      @vm    = FactoryGirl.create(:vm_vmware)
      @user  = FactoryGirl.create(:account_user,  :vm_or_template => @vm, :name => "test")
      @group = FactoryGirl.create(:account_group, :vm_or_template => @vm, :name => "dev")
    end

    it "association" do
      expect(@vm.groups).to     include(@group)
      expect(@vm.groups).not_to include(@user)
    end

    it "with includes" do
      expect(Vm.includes(:groups, :users).where(:accounts => {:name => 'dev'}).count).to eq(1)
    end
  end

  context "#resource_group" do
    before do
      @resource_group = FactoryGirl.create(:resource_group)
      @vm_with_rg     = FactoryGirl.create(:vm_amazon, :resource_group => @resource_group)
      @vm_without_rg  = FactoryGirl.create(:vm_amazon)
    end

    it "has a has_one association with resource groups" do
      expect(@vm_with_rg.resource_group).to eql(@resource_group)
      expect(@vm_without_rg.resource_group).to be_nil
    end
  end

  context "#scan_profile_categories" do
    before do
      @vm = FactoryGirl.create(:vm_vmware)
    end

    it "should produce profile categories without a default or customer profile" do
      categories = @vm.scan_profile_categories(@vm.scan_profile_list)
      expect(categories).to eq VmOrTemplate.default_scan_categories_no_profile
    end

    it "should produce profile categories from the default profile" do
      item_set = ScanItemSet.new
      allow(item_set).to receive(:members) { [FactoryGirl.build(:scan_item_category_default), FactoryGirl.build(:scan_item_file)] }
      allow(ScanItemSet).to receive(:find_by).with(:name => "default") { item_set }

      categories = @vm.scan_profile_categories(@vm.scan_profile_list)
      expect(categories).to match_array ["default", "profiles"]
    end

    it "should produce profile categories from the customer profile" do
      item_set = ScanItemSet.new
      allow(item_set).to receive(:members) { [FactoryGirl.build(:scan_item_category_test), FactoryGirl.build(:scan_item_file)] }
      allow(ScanItemSet).to receive(:find_by).with(:name => "test") { item_set }

      categories = @vm.scan_profile_categories(ScanItem.get_profile("test"))
      expect(categories).to match_array ["test", "profiles"]
    end
  end

  context ".refresh_ems queues refresh for proper class" do
    [:template_vmware, :vm_vmware].each do |vm_or_template|
      let(:instance) { FactoryGirl.create(vm_or_template) }

      it vm_or_template.to_s.classify do
        expect(EmsRefresh).to receive(:queue_refresh).with([[VmOrTemplate, instance.id]])

        instance.class.refresh_ems(instance.id)
      end
    end
  end

  context "#tenant" do
    let(:tenant) { FactoryGirl.create(:tenant) }
    it "has a tenant" do
      vm = FactoryGirl.create(:vm_vmware, :tenant => tenant, :miq_group => nil)
      expect(vm.reload.tenant).to eq(tenant)
      expect(tenant.vm_or_templates).to include(vm)
    end
  end

  context "#supports_migrate?" do
    it "returns true for vmware VM neither orphaned nor archived when queried if it supports migrate operation" do
      vm = FactoryGirl.create(:vm_vmware)
      allow(vm).to receive_messages(:archived? => false)
      allow(vm).to receive_messages(:orphaned? => false)
      expect(vm.supports_migrate?).to eq(true)
    end

    it "returns false for SCVMM VM when queried if it supports migrate operation" do
      vm = FactoryGirl.create(:vm_microsoft)
      expect(vm.supports_migrate?).to eq(false)
    end

    it "returns false for openstack VM  when queried if it supports migrate operation" do
      vm = FactoryGirl.create(:vm_openstack)
      expect(vm.supports_migrate?).to eq(false)
    end
  end

  context "#supports_live_migrate?" do
    it "returns false for vmware VM" do
      vm = FactoryGirl.create(:vm_vmware)
      expect(vm.supports_live_migrate?).to eq(false)
    end

    it "returns false for SCVMM VM" do
      vm = FactoryGirl.create(:vm_microsoft)
      expect(vm.supports_live_migrate?).to eq(false)
    end
  end

  context "#supports_evacuate?" do
    it "returns false for querying vmware VM if it supports evacuate operation" do
      vm =  FactoryGirl.create(:vm_vmware)
      expect(vm.supports_evacuate?).to eq(false)
    end

    it "returns false for querying SCVMM VM if it supports evacuate operation" do
      vm =  FactoryGirl.create(:vm_microsoft)
      expect(vm.supports_evacuate?).to eq(false)
    end
  end

  context "#supports_smartstate_analysis?" do
    it "returns true for VMware VM" do
      vm =  FactoryGirl.create(:vm_vmware)
      allow(vm).to receive_messages(:archived? => false)
      allow(vm).to receive_messages(:orphaned? => false)
      expect(vm.supports_smartstate_analysis?).to eq(true)
    end

    it "returns false for Amazon VM" do
      vm =  FactoryGirl.create(:vm_amazon)
      expect(vm.supports_smartstate_analysis?).to_not eq(true)
    end
  end

  context "#supports_terminate?" do
    let(:ems_does_vm_destroy) { FactoryGirl.create(:ems_vmware) }
    let(:ems_doesnot_vm_destroy) { FactoryGirl.create(:ems_cloud) }
    let(:host) { FactoryGirl.create(:host) }

    it "returns true for a VM not terminated" do
      vm = FactoryGirl.create(:vm, :host => host, :ext_management_system => ems_does_vm_destroy)
      allow(vm).to receive_messages(:terminated? => false)
      expect(vm.supports_terminate?).to eq(true)
    end

    it "returns false for a terminated VM" do
      vm = FactoryGirl.create(:vm, :host => host, :ext_management_system => ems_does_vm_destroy)
      allow(vm).to receive_messages(:terminated? => true)
      expect(vm.supports_terminate?).to eq(false)
      expect(vm.unsupported_reason(:terminate)).to eq("The VM is terminated")
    end

    it "returns false for a provider doesn't support vm_destroy" do
      vm = FactoryGirl.create(:vm, :host => host, :ext_management_system => ems_doesnot_vm_destroy)
      allow(vm).to receive_messages(:terminated? => false)
      expect(vm.supports_terminate?).to eq(false)
      expect(vm.unsupported_reason(:terminate)).to eq("Provider doesn't support vm_destroy")
    end

    it "returns false for a WMware VM" do
      vm = FactoryGirl.create(:vm, :host => host, :ext_management_system => ems_does_vm_destroy)
      allow(vm).to receive_messages(:terminated? => false)
      expect(vm.supports_terminate?).to eq(true)
    end
  end

  context ".set_tenant_from_group" do
    before { Tenant.seed }
    let(:tenant1) { FactoryGirl.create(:tenant) }
    let(:tenant2) { FactoryGirl.create(:tenant) }
    let(:group1) { FactoryGirl.create(:miq_group, :tenant => tenant1) }
    let(:group2) { FactoryGirl.create(:miq_group, :tenant => tenant2) }

    it "assigns the tenant from the group" do
      expect(FactoryGirl.create(:vm_vmware, :miq_group => group1).tenant).to eq(tenant1)
    end

    it "assigns the tenant from the group_id" do
      expect(FactoryGirl.create(:vm_vmware, :miq_group_id => group1.id).tenant).to eq(tenant1)
    end

    it "assigns the tenant from the group over the tenant" do
      expect(FactoryGirl.create(:vm_vmware, :miq_group => group1, :tenant => tenant2).tenant).to eq(tenant1)
    end

    it "uses default tenant via tenancy_mixin" do
      expect(FactoryGirl.create(:vm_vmware).tenant).to eq(Tenant.root_tenant)
    end

    it "changes the tenant after changing the group" do
      vm = FactoryGirl.create(:vm_vmware, :miq_group => group1)
      vm.update_attributes(:miq_group_id => group2.id)
      expect(vm.tenant).to eq(tenant2)
    end
  end

  it "with ems_events" do
    ems       = FactoryGirl.create(:ems_vmware_with_authentication)
    vm        = FactoryGirl.create(:vm_vmware, :ext_management_system => ems)
    ems_event = FactoryGirl.create(:ems_event)
    vm.ems_events << ems_event
    expect(vm.ems_events.first).to be_kind_of(EmsEvent)
    expect(vm.ems_events.first.id).to eq(ems_event.id)
  end

  it "#miq_provision_vms" do
    ems       = FactoryGirl.create(:ems_vmware_with_authentication)
    template  = FactoryGirl.create(:template_vmware, :ext_management_system => ems)
    vm        = FactoryGirl.create(:vm_vmware, :ext_management_system => ems)

    options = {
      :vm_name        => vm.name,
      :vm_target_name => vm.name,
      :src_vm_id      => [template.id, template.name]
    }

    provision = FactoryGirl.create(
      :miq_provision_vmware,
      :destination  => vm,
      :source       => template,
      :request_type => 'clone_to_vm',
      :state        => 'finished',
      :status       => 'Ok',
      :options      => options
    )

    template.miq_provisions_from_template << provision

    expect(template.miq_provision_vms.collect(&:id)).to eq([vm.id])
  end

  describe "#miq_provision_template" do
    it "links vm to template" do
      ems       = FactoryGirl.create(:ems_vmware_with_authentication)
      template  = FactoryGirl.create(:template_vmware, :ext_management_system => ems)
      vm        = FactoryGirl.create(:vm_vmware, :ext_management_system => ems)

      options = {
        :vm_name        => vm.name,
        :vm_target_name => vm.name,
        :src_vm_id      => [template.id, template.name]
      }

      FactoryGirl.create(
        :miq_provision_vmware,
        :destination  => vm,
        :source       => template,
        :request_type => 'clone_to_vm',
        :state        => 'finished',
        :status       => 'Ok',
        :options      => options
      )

      expect(vm.miq_provision_template).to eq(template)
    end
  end

  describe ".v_pct_free_disk_space (delegated to hardware)" do
    let(:vm) { FactoryGirl.create(:vm_vmware, :hardware => hardware) }
    let(:hardware) { FactoryGirl.create(:hardware, :disk_free_space => 20, :disk_capacity => 100) }

    it "calculates in ruby" do
      expect(vm.v_pct_free_disk_space).to eq(20.0)
      expect(vm.v_pct_used_disk_space).to eq(80.0)
    end

    it "calculates in the database" do
      vm.save
      expect(virtual_column_sql_value(VmOrTemplate, "v_pct_free_disk_space")).to eq(20.0)
      expect(virtual_column_sql_value(VmOrTemplate, "v_pct_used_disk_space")).to eq(80.0)
    end

    context "with null disk capacity" do
      let(:hardware) { FactoryGirl.build(:hardware, :disk_free_space => 20, :disk_capacity => nil) }

      it "calculates in ruby" do
        expect(vm.v_pct_free_disk_space).to be_nil
        expect(vm.v_pct_used_disk_space).to be_nil
      end

      it "calculates in the database" do
        vm.save
        expect(virtual_column_sql_value(VmOrTemplate, "v_pct_free_disk_space")).to be_nil
        expect(virtual_column_sql_value(VmOrTemplate, "v_pct_used_disk_space")).to be_nil
      end
    end
  end

  describe "#used_storage" do
    it "calculates in ruby with null hardware" do
      vm = FactoryGirl.create(:vm_vmware)
      expect(vm.used_storage).to eq(0.0)
    end

    it "calculates in ruby" do
      hardware = FactoryGirl.create(:hardware, :memory_mb => 10)
      vm = FactoryGirl.create(:vm_vmware, :hardware => hardware)
      disk = FactoryGirl.create(:disk, :size_on_disk => 1024, :size => 10_240, :hardware => hardware)
      expect(vm.used_storage).to eq(10 * 1024 * 1024 + 1024) # memory_mb + size on disk
    end
  end

  # allocated_disk_storage.to_i + ram_size_in_bytes
  describe "#provisioned_storage" do
    let(:vm) { FactoryGirl.create(:vm_vmware, :hardware => hardware) }
    let(:hardware) { FactoryGirl.create(:hardware, :memory_mb => 10) }
    let(:disk) { FactoryGirl.create(:disk, :size_on_disk => 1024, :size => 10_240, :hardware => hardware) }

    it "calculates in ruby with null hardware" do
      vm = FactoryGirl.create(:vm_vmware)
      expect(vm.provisioned_storage).to eq(0.0)
    end

    it "uses calculated (inline) attribute with null hardware" do
      vm = FactoryGirl.create(:vm_vmware)
      vm2 = VmOrTemplate.select(:id, :provisioned_storage).first
      expect { expect(vm2.provisioned_storage).to eq(0) }.to match_query_limit_of(0)
    end

    it "calculates in ruby" do
      vm
      disk # make sure the record is created
      expect(vm.provisioned_storage).to eq(10_496_000)
    end

    it "uses calculated (inline) attribute" do
      vm
      disk # make sure the record is created
      expect(virtual_column_sql_value(VmOrTemplate, "provisioned_storage")).to eq(10_496_000)
    end
  end

  describe ".ram_size", ".mem_cpu" do
    let(:vm) { FactoryGirl.create(:vm_vmware, :hardware => hardware) }
    let(:hardware) { FactoryGirl.create(:hardware, :memory_mb => 10) }

    it "supports null hardware" do
      vm = FactoryGirl.create(:vm_vmware)
      expect(vm.ram_size).to eq(0)
      expect(vm.mem_cpu).to eq(0)
    end

    it "calculates in ruby" do
      expect(vm.ram_size).to eq(10)
      expect(vm.mem_cpu).to eq(10)
    end

    it "calculates in the database" do
      vm.save
      expect(virtual_column_sql_value(VmOrTemplate, "ram_size")).to eq(10)
      expect(virtual_column_sql_value(VmOrTemplate, "mem_cpu")).to eq(10)
    end
  end

  describe ".ram_size_in_bytes" do
    let(:vm) { FactoryGirl.create(:vm_vmware, :hardware => hardware) }
    let(:hardware) { FactoryGirl.create(:hardware, :memory_mb => 10) }

    it "supports null hardware" do
      vm = FactoryGirl.create(:vm_vmware)
      expect(vm.ram_size_in_bytes).to eq(0)
    end

    it "calculates in ruby" do
      expect(vm.ram_size_in_bytes).to eq(10.megabytes)
    end

    it "calculates in the database" do
      vm.save
      expect(virtual_column_sql_value(VmOrTemplate, "ram_size_in_bytes")).to eq(10.megabytes)
    end
  end

  describe ".cpu_usagemhz_rate_average_max_over_time_period (virtual_attribute)" do
    let(:vm) { FactoryGirl.create :vm_vmware }

    before do
      EvmSpecHelper.local_miq_server
      tp_id = TimeProfile.seed.id
      FactoryGirl.create :metric_rollup_vm_daily,
                         :with_data,
                         :timestamp       => 1.day.ago,
                         :time_profile_id => tp_id,
                         :resource_id     => vm.id,
                         :min_max         => {
                           :abs_max_cpu_usagemhz_rate_average_value => 100.00
                         }

      FactoryGirl.create :metric_rollup_vm_daily,
                         :with_data,
                         :cpu_usagemhz_rate_average => 10.0,
                         :timestamp                 => 1.day.ago,
                         :time_profile_id           => tp_id,
                         :resource_id               => vm.id,
                         :min_max                   => {
                           :abs_max_cpu_usagemhz_rate_average_value => 900.00
                         }
      FactoryGirl.create :metric_rollup_vm_daily,
                         :with_data,
                         :cpu_usagemhz_rate_average => 100.0,
                         :timestamp                 => 1.day.ago,
                         :time_profile_id           => tp_id,
                         :resource_id               => vm.id,
                         :min_max                   => {
                           :abs_max_cpu_usagemhz_rate_average_value => 500.00
                         }
    end

    it "calculates in ruby" do
      expect(vm.cpu_usagemhz_rate_average_max_over_time_period).to eq(900.00)
    end

    it "calculates in the database" do
      expect(
        virtual_column_sql_value(
          VmOrTemplate,
          "cpu_usagemhz_rate_average_max_over_time_period"
        )
      ).to eq(100.0)
    end
  end

  describe ".derived_memory_used_max_over_time_period (virtual_attribute)" do
    let(:vm) { FactoryGirl.create :vm_vmware }

    before do
      EvmSpecHelper.local_miq_server
      tp_id = TimeProfile.seed.id
      FactoryGirl.create :metric_rollup_vm_daily,
                         :with_data,
                         :time_profile_id => tp_id,
                         :timestamp       => 1.day.ago,
                         :resource_id     => vm.id,
                         :min_max         => {
                           :abs_max_derived_memory_used_value => 100.00
                         }
      FactoryGirl.create :metric_rollup_vm_daily,
                         :with_data,
                         :derived_memory_used => 10.0,
                         :timestamp           => 1.day.ago,
                         :time_profile_id     => tp_id,
                         :resource_id         => vm.id,
                         :min_max             => {
                           :abs_max_derived_memory_used_value => 500.00
                         }
      FactoryGirl.create :metric_rollup_vm_daily,
                         :with_data,
                         :derived_memory_used => 1000.0,
                         :timestamp           => 1.day.ago,
                         :time_profile_id     => tp_id,
                         :resource_id         => vm.id,
                         :min_max             => {
                           :abs_max_derived_memory_used_value => 200.00
                         }
    end

    it "calculates in ruby" do
      expect(vm.derived_memory_used_max_over_time_period).to eq(500.0)
    end

    it "calculates in the database" do
      expect(
        virtual_column_sql_value(
          VmOrTemplate,
          "derived_memory_used_max_over_time_period"
        )
      ).to eq(1000.0)
    end
  end

  describe ".host_name" do
    let(:vm) { FactoryGirl.create(:vm_vmware, :host => host) }
    let(:host) { FactoryGirl.create(:host_vmware, :name => "our host") }

    it "calculates in ruby" do
      expect(vm.host_name).to eq("our host")
    end

    it "calculates in the database" do
      vm.save
      expect(virtual_column_sql_value(VmOrTemplate, "host_name")).to eq("our host")
    end
  end

  describe ".v_host_vmm_product" do
    it "delegates to host" do
      host = FactoryGirl.build(:host, :vmm_product => "Hyper-V")
      vm = FactoryGirl.build(:vm_vmware, :host => host)

      expect(vm.v_host_vmm_product).to eq("Hyper-V")
    end
  end

  describe ".active" do
    it "detects active" do
      vm.update_attributes(:ext_management_system => ems)
      expect(vm).to be_active
      expect(virtual_column_sql_value(VmOrTemplate, "active")).to be true
    end

    it "detects non-active" do
      vm.update_attributes(:ext_management_system => nil)
      expect(vm).not_to be_active
      expect(virtual_column_sql_value(VmOrTemplate, "active")).to be false
    end
  end

  describe ".archived" do
    it "detects archived" do
      vm.update_attributes(:ext_management_system => nil, :storage => nil)
      expect(vm).to be_archived
      expect(virtual_column_sql_value(VmOrTemplate, "archived")).to be true
    end

    it "detects non-archived (has ems and storage)" do
      vm.update_attributes(:ext_management_system => ems, :storage => storage)
      expect(vm).not_to be_archived
      expect(virtual_column_sql_value(VmOrTemplate, "archived")).to be false
    end

    it "detects non-archived (has ems)" do
      vm.update_attributes(:ext_management_system => ems, :storage => nil)
      expect(vm).not_to be_archived
      expect(virtual_column_sql_value(VmOrTemplate, "archived")).to be false
    end

    it "detects non-archived (has storage)" do
      vm.update_attributes(:ext_management_system => nil, :storage => storage)
      expect(virtual_column_sql_value(VmOrTemplate, "archived")).to be false
      expect(vm).not_to be_archived
      vm.ext_management_system = nil
    end
  end

  describe ".orphaned" do
    it "detects orphaned" do
      vm.update_attributes(:ext_management_system => nil, :storage => storage)
      expect(vm).to be_orphaned
      expect(virtual_column_sql_value(VmOrTemplate, "orphaned")).to be true
    end

    it "detects non-orphaned (ems and no storage)" do
      vm.update_attributes(:ext_management_system => ems, :storage => nil)
      expect(vm).not_to be_orphaned
      expect(virtual_column_sql_value(VmOrTemplate, "orphaned")).to be false
    end

    it "detects non-orphaned (no storage)" do
      vm.update_attributes(:ext_management_system => nil, :storage => nil)
      expect(vm).not_to be_orphaned
      expect(virtual_column_sql_value(VmOrTemplate, "orphaned")).to be false
    end

    it "detects non-orphaned (has ems)" do
      vm.update_attributes(:ext_management_system => ems, :storage => storage)
      expect(vm).not_to be_orphaned
      expect(virtual_column_sql_value(VmOrTemplate, "orphaned")).to be false
    end
  end

  describe "connected_to_ems?" do
    let(:vm) { FactoryGirl.create(:vm_vmware, :connection_state => "connected") }
    let(:vm2) { FactoryGirl.create(:vm_vmware, :connection_state => "disconnected") }
    let(:vm3) { FactoryGirl.create(:vm_vmware, :connection_state => nil) }

    it "detects nil" do
      expect(vm3).to be_connected_to_ems
    end

    it "detects connected" do
      expect(vm).to be_connected_to_ems
    end

    it "detects disconnected" do
      expect(vm2).not_to be_connected_to_ems
    end
  end

  describe ".disconnected?" do
    let(:vm) { FactoryGirl.create(:vm_vmware, :connection_state => "connected") }
    let(:vm2) { FactoryGirl.create(:vm_vmware, :connection_state => "disconnected") }
    let(:vm3) { FactoryGirl.create(:vm_vmware, :connection_state => nil) }

    it "detects nil" do
      expect(vm3).not_to be_disconnected
      expect(virtual_column_sql_value(VmOrTemplate, "disconnected")).to be_falsey
    end

    it "detects connected" do
      expect(vm).not_to be_disconnected
      expect(virtual_column_sql_value(VmOrTemplate, "disconnected")).to be_falsey
    end

    it "detects disconnected" do
      expect(vm2).to be_disconnected
      expect(virtual_column_sql_value(VmOrTemplate, "disconnected")).to be_truthy
    end
  end

  describe ".v_is_a_template" do
    it "detects nil" do
      vm.update_attribute(:template, nil) # sorry, but wanted a nil in there
      expect(vm.v_is_a_template).to eq("False")
      expect(virtual_column_sql_value(VmOrTemplate, "v_is_a_template")).to eq(false)
    end

    it "detects false" do
      vm.update_attributes(:template => false)
      expect(vm.v_is_a_template).to eq("False")
      expect(virtual_column_sql_value(VmOrTemplate, "v_is_a_template")).to eq(false)
    end

    it "detects true" do
      vm.update_attributes(:template => true)
      expect(vm.v_is_a_template).to eq("True")
      expect(virtual_column_sql_value(VmOrTemplate, "v_is_a_template")).to eq(true)
    end
  end

  describe ".v_annotation" do
    let(:vm) { FactoryGirl.create(:vm) }
    it "handles no hardware" do
      expect(vm.v_annotation).to be_nil
    end

    it "handles hardware" do
      FactoryGirl.create(:hardware, :vm => vm, :annotation => "the annotation")
      expect(vm.v_annotation).to eq("the annotation")
    end
  end

  describe ".cpu_total_cores" do
    let(:vm) { FactoryGirl.create(:vm) }
    it "handles no hardware" do
      expect(vm.cpu_total_cores).to eq(0)
    end

    it "handles hardware" do
      FactoryGirl.create(:hardware, :vm => vm, :cpu_total_cores => 8)
      expect(vm.cpu_total_cores).to eq(8)
    end

    it "calculates in the database" do
      FactoryGirl.create(:hardware, :vm => vm, :cpu_total_cores => 8)
      expect(virtual_column_sql_value(VmOrTemplate, "cpu_total_cores")).to eq(8)
    end
  end

  describe ".cpu_cores_per_socket" do
    let(:vm) { FactoryGirl.create(:vm) }
    it "handles no hardware" do
      expect(vm.cpu_cores_per_socket).to eq(0)
    end

    it "handles hardware" do
      FactoryGirl.create(:hardware, :vm => vm, :cpu_cores_per_socket => 4)
      expect(vm.cpu_cores_per_socket).to eq(4)
    end

    it "calculates in the database" do
      FactoryGirl.create(:hardware, :vm => vm, :cpu_cores_per_socket => 4)
      expect(virtual_column_sql_value(VmOrTemplate, "cpu_cores_per_socket")).to eq(4)
    end
  end

  describe "#disconnect_ems" do
    let(:ems) { FactoryGirl.build(:ext_management_system) }
    let(:vm) do
      FactoryGirl.build(:vm_or_template,
                        :ext_management_system => ems,
                        :ems_cluster           => FactoryGirl.build(:ems_cluster))
    end

    it "clears ems and cluster" do
      vm.disconnect_ems(ems)
      expect(vm.ext_management_system).to be_nil
      expect(vm.ems_cluster).to be_nil
    end

    it "doesnt clear the wrong ems" do
      vm.disconnect_ems(FactoryGirl.build(:ext_management_system))
      expect(vm.ext_management_system).not_to be_nil
      expect(vm.ems_cluster).not_to be_nil
    end
  end

  describe "#all_archived" do
    let(:ems) { FactoryGirl.build(:ext_management_system) }
    it "works" do
      FactoryGirl.create(:vm_or_template, :ext_management_system => ems)
      arch = FactoryGirl.create(:vm_or_template)
      FactoryGirl.create(:vm_or_template, :storage => FactoryGirl.create(:storage))

      expect(VmOrTemplate.archived).to eq([arch])
    end
  end

  describe "#all_orphaned" do
    it "works" do
      FactoryGirl.create(:vm_or_template, :ext_management_system => ems)
      FactoryGirl.create(:vm_or_template)
      orph = FactoryGirl.create(:vm_or_template, :storage => FactoryGirl.create(:storage))

      expect(VmOrTemplate.orphaned).to eq([orph])
    end
  end

  describe "#all_archived_or_orphaned" do
    it "works" do
      vm = FactoryGirl.create(:vm_or_template, :ext_management_system => ems)
      FactoryGirl.create(:vm_or_template)
      FactoryGirl.create(:vm_or_template, :storage => FactoryGirl.create(:storage))

      expect(VmOrTemplate.with_ems).to eq([vm])
    end
  end

  describe ".post_refresh_ems" do
    let(:folder_blue1)   { EmsFolder.find_by(:name => "blue1") }
    let(:folder_blue2)   { EmsFolder.find_by(:name => "blue2") }
    let(:folder_vm_root) { EmsFolder.find_by(:name => "vm") }
    let(:vm_blue1)       { VmOrTemplate.find_by(:name => "vm_blue1") }
    let(:vm_blue2)       { VmOrTemplate.find_by(:name => "vm_blue2") }

    let!(:ems) do
      _, _, zone = EvmSpecHelper.local_guid_miq_server_zone
      FactoryGirl.create(:ems_vmware, :zone => zone).tap do |ems|
        build_vmware_folder_structure!(ems)
        folder_blue1.add_child(FactoryGirl.create(:vm_vmware, :name => "vm_blue1", :ems_id => ems.id))
        folder_blue2.add_child(FactoryGirl.create(:vm_vmware, :name => "vm_blue2", :ems_id => ems.id))
      end
    end

    let!(:start_time) { Time.now.utc }

    it "when a folder is created under a folder" do
      new_folder = FactoryGirl.create(:vmware_folder_vm, :ems_id => ems.id)
      new_folder.parent = folder_blue1

      described_class.post_refresh_ems(ems.id, start_time)

      expect(MiqQueue.count).to eq(0)
    end

    it "when a folder is renamed" do
      folder_blue1.update_attributes(:name => "new blue1")

      described_class.post_refresh_ems(ems.id, start_time)

      expect(MiqQueue.count).to eq(1)
      expect(MiqQueue.first).to have_attributes(
        :class_name  => vm_blue1.class.name,
        :instance_id => vm_blue1.id,
        :method_name => "classify_with_parent_folder_path"
      )
    end

    it "when a folder is moved" do
      folder_blue1.parent = folder_blue2

      described_class.post_refresh_ems(ems.id, start_time)

      expect(MiqQueue.count).to eq(1)
      expect(MiqQueue.first).to have_attributes(
        :class_name  => vm_blue1.class.name,
        :instance_id => vm_blue1.id,
        :method_name => "classify_with_parent_folder_path"
      )
    end

    it "when a VM is created under a folder" do
      new_vm = FactoryGirl.create(:vm_vmware, :ems_id => ems.id)
      new_vm.with_relationship_type("ems_metadata") { |v| v.parent = folder_blue1 }

      described_class.post_refresh_ems(ems.id, start_time)

      expect(MiqQueue.count).to eq(1)
      expect(MiqQueue.first).to have_attributes(
        :class_name  => new_vm.class.name,
        :instance_id => new_vm.id,
        :method_name => "post_create_actions"
      )
    end

    it "when a VM is moved to another folder" do
      vm_blue1.with_relationship_type("ems_metadata") { |v| v.parent = folder_blue2 }

      described_class.post_refresh_ems(ems.id, start_time)

      expect(MiqQueue.count).to eq(1)
      expect(MiqQueue.first).to have_attributes(
        :class_name  => vm_blue1.class.name,
        :instance_id => vm_blue1.id,
        :method_name => "classify_with_parent_folder_path"
      )
    end

    it "when a folder is created and a folder is moved under it simultaneously" do
      new_folder = FactoryGirl.create(:vmware_folder_vm, :ems_id => ems.id)
      new_folder.parent = folder_vm_root
      folder_blue1.parent = new_folder

      described_class.post_refresh_ems(ems.id, start_time)

      expect(MiqQueue.count).to eq(1)
      expect(MiqQueue.first).to have_attributes(
        :class_name  => vm_blue1.class.name,
        :instance_id => vm_blue1.id,
        :method_name => "classify_with_parent_folder_path"
      )
    end

    it "when a folder is renamed and a folder is moved under it simultaneously" do
      folder_blue1.update_attributes(:name => "new blue1")
      folder_blue2.parent = folder_blue1

      described_class.post_refresh_ems(ems.id, start_time)

      queue_items = MiqQueue.order(:instance_id)
      expect(queue_items.count).to eq(2)
      expect(queue_items[0]).to have_attributes(
        :class_name  => vm_blue1.class.name,
        :instance_id => vm_blue1.id,
        :method_name => "classify_with_parent_folder_path"
      )
      expect(queue_items[1]).to have_attributes(
        :class_name  => vm_blue2.class.name,
        :instance_id => vm_blue2.id,
        :method_name => "classify_with_parent_folder_path"
      )
    end

    it "when a folder is created and a VM is moved under it simultaneously" do
      new_folder = FactoryGirl.create(:vmware_folder_vm, :ems_id => ems.id)
      new_folder.parent = folder_vm_root
      vm_blue1.with_relationship_type("ems_metadata") { |v| v.parent = new_folder }

      described_class.post_refresh_ems(ems.id, start_time)

      expect(MiqQueue.count).to eq(1)
      expect(MiqQueue.first).to have_attributes(
        :class_name  => vm_blue1.class.name,
        :instance_id => vm_blue1.id,
        :method_name => "classify_with_parent_folder_path"
      )
    end

    it "when a folder is renamed and a VM is moved under it simultaneously" do
      folder_blue2.update_attributes(:name => "new blue2")
      vm_blue1.with_relationship_type("ems_metadata") { |v| v.parent = folder_blue2 }

      described_class.post_refresh_ems(ems.id, start_time)

      queue_items = MiqQueue.order(:instance_id)
      expect(queue_items.count).to eq(2)
      expect(queue_items[0]).to have_attributes(
        :class_name  => vm_blue1.class.name,
        :instance_id => vm_blue1.id,
        :method_name => "classify_with_parent_folder_path"
      )
      expect(queue_items[1]).to have_attributes(
        :class_name  => vm_blue2.class.name,
        :instance_id => vm_blue2.id,
        :method_name => "classify_with_parent_folder_path"
      )
    end
  end

  context "#v_datastore_path" do
    it "with no location or storage" do
      expect(Vm.new.v_datastore_path).to eq("")
    end

    it "with location but no storage" do
      expect(Vm.new(:location => "test location").v_datastore_path).to eq("test location")
    end

    it "with location and storage" do
      storage = Storage.new(:name => "storage name")
      expect(Vm.new(:location => "test location", :storage => storage).v_datastore_path).to eq("storage name/test location")
    end
  end

  context "#policy_events" do
    it "returns the policy events with target class of VmOrTemplate and target_id of the vm" do
      policy_event = FactoryGirl.create(:policy_event, :target_class => "VmOrTemplate", :target_id => vm.id)

      expect(vm.policy_events).to eq([policy_event])
    end
  end

  describe '#normalized_state' do
    let(:klass) { :vm_vmware }
    let(:storage) { FactoryGirl.create(:storage_vmware) }
    let(:ems) { FactoryGirl.create(:ems_vmware) }
    let(:connection_state) { 'disconnected' }
    let(:retired) { false }

    let!(:vm) do
      FactoryGirl.create(klass, :storage          => storage,
                                :ems_id           => ems.try(:id),
                                :connection_state => connection_state,
                                :retired          => retired)
    end

    subject { vm.normalized_state }

    shared_examples 'normalized_state return value' do |value|
      let(:virtual_attribute) { virtual_column_sql_value(VmOrTemplate, "normalized_state") }

      it { is_expected.to eq(value) }

      it 'virtual column' do
        expect(virtual_attribute).to eq(value)
      end
    end

    context 'no ems and no storage attached' do
      let(:ems) { nil }
      let(:storage) { nil }

      include_examples "normalized_state return value", "archived"
    end

    context 'no ems attached' do
      let(:ems) { nil }

      include_examples "normalized_state return value", "orphaned"
    end

    context 'template' do
      let(:klass) { :template_vmware }

      include_examples "normalized_state return value", "template"
    end

    context 'retired' do
      let(:retired) { true }

      include_examples "normalized_state return value", "retired"
    end

    context 'disconnected' do
      include_examples "normalized_state return value", "disconnected"
    end

    context 'valid powerstate' do
      let(:connection_state) { 'connected' }

      include_examples "normalized_state return value", "on"
    end
  end
end
