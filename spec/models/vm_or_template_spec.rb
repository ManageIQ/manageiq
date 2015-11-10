require "spec_helper"

describe VmOrTemplate do
  context ".event_by_property" do
    context "should add an EMS event" do
      before(:each) do
        Timecop.freeze(Time.now)

        @host            = FactoryGirl.create(:host,      :name  => "host")
        @vm              = FactoryGirl.create(:vm_vmware, :host  => @host, :name => "vm", :uid_ems => "1", :ems_id => 101)

        @event_type      = "foo"
        @event_timestamp = Time.now.utc
      end

      after(:each) do
        Timecop.return
      end

      it "by IP Address" do
        ipaddress       = "192.268.20.1"
        hardware        = FactoryGirl.create(:hardware,  :vm_or_template_id => @vm.id,       :host     => @host)
        network         = FactoryGirl.create(:network,   :hardware_id       => hardware.id, :ipaddress => ipaddress)
        event_msg       = "Add EMS Event by IP address"

        VmOrTemplate.any_instance.should_receive(:add_ems_event).with(@event_type, event_msg, @event_timestamp)
        VmOrTemplate.event_by_property("ipaddress", ipaddress, @event_type, event_msg)
      end

      it "by UID EMS" do
        event_msg = "Add EMS Event by UID EMS"

        VmOrTemplate.any_instance.should_receive(:add_ems_event).with(@event_type, event_msg, @event_timestamp)
        VmOrTemplate.event_by_property("uid_ems", "1", @event_type, event_msg)
      end
    end

    it "should raise an error" do
      err = "Unsupported property type [foo]"
      -> { VmOrTemplate.event_by_property('foo', '', '', '') }.should raise_error(err)
    end
  end

  context "#add_ems_event" do
    before(:each) do
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
      before(:each) do
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

        EmsEvent.should_receive(:add).with(@vm.ems_id, @event_hash)
        @vm.add_ems_event(@event_type, event_msg, @event_timestamp)
      end

      it "with no host" do
        vm_no_host       = FactoryGirl.create(:vm_vmware, :name => "vm 2", :location => "/local/path", :uid_ems => "2", :ems_id => 102)
        ipaddress        = "192.268.20.2"
        hardware_no_host = FactoryGirl.create(:hardware, :vm_or_template_id => vm_no_host.id)
        network_no_host  = FactoryGirl.create(:network,  :hardware_id       => hardware_no_host.id, :ipaddress => ipaddress)

        event_msg = "Add EMS Event by IP address with no host"
        @event_hash[:message]           = event_msg
        @event_hash[:vm_or_template_id] = vm_no_host.id
        @event_hash[:vm_name]           = vm_no_host.name
        @event_hash[:vm_location]       = vm_no_host.location
        @event_hash[:ems_id]            = vm_no_host.ems_id

        EmsEvent.should_receive(:add).with(vm_no_host.ems_id, @event_hash)
        vm_no_host.add_ems_event(@event_type, event_msg, @event_timestamp)
      end

      it "with no ems id" do
        vm_no_ems       = FactoryGirl.create(:vm_vmware, :name => "vm 3", :location => "/local/path", :host => @host)
        ipaddress       = "192.268.20.3"
        hardware_no_ems = FactoryGirl.create(:hardware, :vm_or_template_id => vm_no_ems.id)
        network_no_ems  = FactoryGirl.create(:network,  :hardware_id       => hardware_no_ems.id, :ipaddress => ipaddress)

        event_msg = "Add EMS Event by IP address with no ems id"
        @event_hash[:message]           = event_msg
        @event_hash[:vm_or_template_id] = vm_no_ems.id
        @event_hash[:vm_name]           = vm_no_ems.name
        @event_hash[:vm_location]       = vm_no_ems.location
        @event_hash[:host_id]           = vm_no_ems.host_id
        @event_hash[:host_name]         = @host.name

        EmsEvent.should_receive(:add).with(nil, @event_hash)
        vm_no_ems.add_ems_event(@event_type, event_msg, @event_timestamp)
      end

      it "with no host and no ems id" do
        vm_no_host_no_ems       = FactoryGirl.create(:vm_vmware, :name => "vm 4", :location => "/local/path")
        ipaddress               = "192.268.20.4"
        hardware_no_host_no_ems = FactoryGirl.create(:hardware, :vm_or_template_id => vm_no_host_no_ems.id)
        network_no_host_no_ems  = FactoryGirl.create(:network,  :hardware_id       => hardware_no_host_no_ems.id, :ipaddress => ipaddress)

        event_msg = "Add EMS Event by IP address with no host and no ems id"
        @event_hash[:message]           = event_msg
        @event_hash[:vm_or_template_id] = vm_no_host_no_ems.id
        @event_hash[:vm_name]           = vm_no_host_no_ems.name
        @event_hash[:vm_location]       = vm_no_host_no_ems.location

        EmsEvent.should_receive(:add).with(nil, @event_hash)
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
      @vm.reconfigured_hardware_value?(@options).should be_false
    end

    context "with a drift state" do
      before { @vm.save_drift_state }

      context "with increased operator" do
        before { @options[:operator] = "increased" }

        it "with the same memory value" do
          @vm.save_drift_state

          @vm.reconfigured_hardware_value?(@options).should be_false
        end

        it "with a lower memory value" do
          @vm.hardware.memory_mb = 512
          @vm.save_drift_state

          @vm.reconfigured_hardware_value?(@options).should be_false
        end

        it "with a higher memory value" do
          @vm.hardware.memory_mb = 2048
          @vm.save_drift_state

          @vm.reconfigured_hardware_value?(@options).should be_true
        end
      end

      context "with decreased operator" do
        before { @options[:operator] = "decreased" }

        it "with the same memory value" do
          @vm.save_drift_state

          @vm.reconfigured_hardware_value?(@options).should be_false
        end

        it "with a lower memory value" do
          @vm.hardware.memory_mb = 512
          @vm.save_drift_state

          @vm.reconfigured_hardware_value?(@options).should be_true
        end

        it "with a higher memory value" do
          @vm.hardware.memory_mb = 2048
          @vm.save_drift_state

          @vm.reconfigured_hardware_value?(@options).should be_false
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
                                 :vendor   => 'VMware',
                                 :storage  => @storage1,
                                 :storages => [@storage1, @storage2])
        @zone = FactoryGirl.create(:zone, :name => 'zone')

        MiqServer.any_instance.stub(:is_vix_disk? => true)
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
        @vm.miq_server_proxies.should == [@svr1]
      end

      it "should select SmartProxies without host affinity when the VM host has no affinity" do
        @svr1.vm_scan_host_affinity = [@host2]
        @svr2.vm_scan_host_affinity = [@host2]
        @vm.miq_server_proxies.should == [@svr3]
      end

      it "should select SmartProxies with matching VM storage affinity" do
        @svr1.vm_scan_storage_affinity = [@storage1, @storage2]
        @svr2.vm_scan_storage_affinity = [@storage2]
        @vm.miq_server_proxies.should == [@svr1]
      end

      it "should select SmartProxies without storage affinity when the VM storage has no affinity" do
        @svr1.vm_scan_storage_affinity = [@storage3]
        @svr2.vm_scan_storage_affinity = [@storage3]
        @vm.miq_server_proxies.should == [@svr3]
      end

      it "should not select SmartProxies without matching VM storage affinity for all disks" do
        @svr1.vm_scan_storage_affinity = [@storage1]
        @svr2.vm_scan_storage_affinity = [@storage2]
        @vm.miq_server_proxies.should == []
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
                                 :vendor   => 'RedHat',
                                 :storage  => @storage1,
                                 :storages => [@storage1])

        @svr1 = EvmSpecHelper.local_miq_server(:name => 'svr1')
        @svr2 = FactoryGirl.create(:miq_server, :name => 'svr2', :zone => @svr1.zone)

        @svr1_vm = FactoryGirl.create(:vm_redhat, :host => @host1, :name => 'svr1_vm', :miq_server => @svr1)
        @svr1_vm = FactoryGirl.create(:vm_redhat, :host => @host2, :name => 'svr2_vm', :miq_server => @svr2)
      end

      it "should select SmartProxies with access to the same NFS storage" do
        @storage1.store_type = 'NFS'
        Vm.should_receive(:miq_servers_for_scan).and_return([@svr1, @svr2])
        @vm.miq_server_proxies.should == [@svr1]
      end

      it "should select SmartProxies for a powered-off VM" do
        Vm.should_receive(:miq_servers_for_scan).and_return([@svr1, @svr2])
        # RHEV VMs do not have an associated host when powered off
        @vm.host = nil
        @vm.miq_server_proxies.should == [@svr1]
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

  describe ".cloneable?" do
    context "when the vm_or_template does not exist" do
      it "returns false" do
        expect(VmOrTemplate.cloneable?(111)).to eq(false)
      end
    end

    context "when the vm_or_template does exist but is not cloneable" do
      let(:vm_or_template) { VmOrTemplate.create(:type => "ManageIQ::Providers::Redhat::InfraManager::Template", :name => "aaa", :location => "bbb", :vendor => "redhat") }

      it "returns false" do
        expect(VmOrTemplate.cloneable?(vm_or_template.id)).to eq(false)
      end
    end

    context "when the vm_or_template exists and is cloneable" do
      let(:vm_or_template) { ManageIQ::Providers::Redhat::InfraManager::Vm.create(:type => "ManageIQ::Providers::Redhat::InfraManager::Vm", :name => "aaa", :location => "bbb", :vendor   => "redhat") }

      it "returns true" do
        expect(VmOrTemplate.cloneable?(vm_or_template.id)).to eq(true)
      end
    end
  end

  context "#scan_profile_categories" do
    before do
      @vm = FactoryGirl.create(:vm_vmware)
    end

    it "should produce profile categories without a default or customer profile" do
      categories = @vm.scan_profile_categories(@vm.scan_profile_list)
      categories.should eq VmOrTemplate.default_scan_categories_no_profile
    end

    it "should produce profile categories from the default profile" do
      item_set = ScanItemSet.new
      item_set.stub(:members) { [FactoryGirl.build(:scan_item_category_default), FactoryGirl.build(:scan_item_file)] }
      ScanItemSet.stub(:find_by_name).with("default") { item_set }

      categories = @vm.scan_profile_categories(@vm.scan_profile_list)
      categories.should match_array ["default", "profiles"]
    end

    it "should produce profile categories from the customer profile" do
      item_set = ScanItemSet.new
      item_set.stub(:members) { [FactoryGirl.build(:scan_item_category_test), FactoryGirl.build(:scan_item_file)] }
      ScanItemSet.stub(:find_by_name).with("test") { item_set }

      categories = @vm.scan_profile_categories(ScanItem.get_profile("test"))
      categories.should match_array ["test", "profiles"]
    end
  end

  context "Status Methods" do
    let(:vm)      { FactoryGirl.create(:vm_or_template) }
    let(:ems)     { FactoryGirl.create(:ext_management_system) }
    let(:storage) { FactoryGirl.create(:storage) }

    context "with EMS" do
      before { vm.ext_management_system = ems }
      it { expect(vm).to be_active }
    end

    context "without EMS" do
      it { expect(vm).to be_archived }
      context "with storage" do
        before { vm.storage = storage }
        it { expect(vm).to be_orphaned }
      end
    end
  end

  context ".refresh_ems queues refresh for proper class" do
    [:template_vmware, :vm_vmware].each do |vm_or_template|
      let(:instance) { FactoryGirl.create(vm_or_template) }

      it "#{vm_or_template.to_s.classify}" do
        EmsRefresh.should_receive(:queue_refresh).with([[VmOrTemplate, instance.id]])

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

  context "#is_available?" do
    it "returns true for SCVMM VM" do
      vm =  FactoryGirl.create(:vm_vmware)
      expect(vm.is_available?(:migrate)).to eq(true)
    end

    it "returns true for vmware VM" do
      vm =  FactoryGirl.create(:vm_microsoft)
      expect(vm.is_available?(:migrate)).to_not eq(true)
    end
  end

  context "#is_available? for Smartstate Analysis" do
    it "returns true for VMware VM" do
      vm =  FactoryGirl.create(:vm_vmware)
      vm.stub(:archived? => false)
      vm.stub(:orphaned? => false)
      expect(vm.is_available?(:smartstate_analysis)).to eq(true)
    end

    it "returns false for Amazon VM" do
      vm =  FactoryGirl.create(:vm_amazon)
      expect(vm.is_available?(:smartstate_analysis)).to_not eq(true)
    end
  end

  context "#self.batch_operation_supported?" do
    it "when the vm_or_template supports migrate,  returns false" do
      vm1 =  FactoryGirl.create(:vm_microsoft)
      vm2 =  FactoryGirl.create(:vm_vmware)
      expect(VmOrTemplate.batch_operation_supported?(:migrate, [vm1.id, vm2.id])).to eq(false)
    end

    it "when the vm_or_template exists and can be migrated, returns true" do
      vm1 =  FactoryGirl.create(:vm_vmware)
      vm2 =  FactoryGirl.create(:vm_vmware)
      expect(VmOrTemplate.batch_operation_supported?(:migrate, [vm1.id, vm2.id])).to eq(true)
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
end
