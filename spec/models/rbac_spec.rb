describe Rbac do
  before { allow(User).to receive_messages(:server_timezone => "UTC") }
  let(:default_tenant) { Tenant.seed }

  let(:owner_tenant) { FactoryGirl.create(:tenant) }
  let(:owner_group)  { FactoryGirl.create(:miq_group, :tenant => owner_tenant) }
  let(:owner_user)   { FactoryGirl.create(:user, :miq_groups => [owner_group]) }
  let(:owned_vm)     { FactoryGirl.create(:vm_vmware, :tenant => owner_tenant) }

  let(:other_tenant) { FactoryGirl.create(:tenant) }
  let(:other_group)  { FactoryGirl.create(:miq_group, :tenant => other_tenant) }
  let(:other_user)   { FactoryGirl.create(:user, :miq_groups => [other_group]) }
  let(:other_vm)     { FactoryGirl.create(:vm_vmware, :tenant => other_tenant) }

  let(:child_tenant) { FactoryGirl.create(:tenant, :divisible => false, :parent => owner_tenant) }
  let(:child_group)  { FactoryGirl.create(:miq_group, :tenant => child_tenant) }
  let(:child_openstack_vm) { FactoryGirl.create(:vm_openstack, :tenant => child_tenant, :miq_group => child_group) }

  describe ".search" do
    describe "with find_options_for_tenant filtering (basic) all resources" do
      {
        "ExtManagementSystem"    => :ems_vmware,
        "MiqAeDomain"            => :miq_ae_domain,
        # "MiqRequest"           => :miq_request,  # MiqRequest can't be instantuated, it is an abstract class
        "MiqRequestTask"         => :miq_request_task,
        "Provider"               => :provider,
        "Service"                => :service,
        "ServiceTemplate"        => :service_template,
        "ServiceTemplateCatalog" => :service_template_catalog,
        "Vm"                     => :vm_vmware
      }.each do |klass, factory_name|
        it "with :user finds #{klass}" do
          owned_resource = FactoryGirl.create(factory_name, :tenant => owner_tenant)
          _other_resource = FactoryGirl.create(factory_name, :tenant => other_tenant)
          results = Rbac.filtered(klass, :user => owner_user)
          expect(results).to match_array [owned_resource]
        end
      end
    end

    describe "with find_options_for_tenant filtering" do
      before do
        owned_vm # happy path
        other_vm # sad path
      end

      it "with User.with_user finds Vm" do
        User.with_user(owner_user) do
          results = Rbac.search(:class => "Vm", :results_format => :objects).first
          expect(results).to match_array [owned_vm]
        end
      end

      it "with :user finds Vm" do
        results = Rbac.search(:class => "Vm", :results_format => :objects, :user => owner_user).first
        expect(results).to match_array [owned_vm]
      end

      it "with :userid finds Vm" do
        results = Rbac.search(:class => "Vm", :results_format => :objects, :userid => owner_user.userid).first
        expect(results).to match_array [owned_vm]
      end

      it "with :miq_group, finds Vm" do
        results = Rbac.search(:class => "Vm", :results_format => :objects, :miq_group => owner_group).first
        expect(results).to match_array [owned_vm]
      end

      it "with :miq_group_id finds Vm" do
        results = Rbac.search(:class => "Vm", :results_format => :objects, :miq_group_id => owner_group.id).first
        expect(results).to match_array [owned_vm]
      end

      it "leaving tenant doesnt find Vm" do
        owner_user.update_attributes(:miq_groups => [other_user.current_group])
        User.with_user(owner_user) do
          results = Rbac.search(:class => "Vm", :results_format => :objects).first
          expect(results).to match_array [other_vm]
        end
      end

      describe "with accessible_tenant_ids filtering (strategy = :descendants_id)" do
        it "can't see parent tenant's Vm" do
          results = Rbac.search(:class => "Vm", :results_format => :objects, :miq_group => child_group).first
          expect(results).to match_array []
        end

        it "can see descendant tenant's Vms" do
          child_vm = FactoryGirl.create(:vm_vmware, :tenant => child_tenant)

          results = Rbac.search(:class => "Vm", :results_format => :objects, :miq_group => owner_group).first
          expect(results).to match_array [owned_vm, child_vm]
        end

        it "can see descendant tenant's Openstack Vm" do
          child_openstack_vm

          results = Rbac.search(:class => "ManageIQ::Providers::Openstack::CloudManager::Vm", :results_format => :objects, :miq_group => owner_group).first
          expect(results).to match_array [child_openstack_vm]
        end
      end

      context "with accessible_tenant_ids filtering (strategy = :parent_ids)" do
        it "can see parent tenant's EMS" do
          ems = FactoryGirl.create(:ems_vmware, :tenant => owner_tenant)
          results = Rbac.search(:class => "ExtManagementSystem", :results_format => :objects, :miq_group => child_group).first
          expect(results).to match_array [ems]
        end

        it "can't see descendant tenant's EMS" do
          _ems = FactoryGirl.create(:ems_vmware, :tenant => child_tenant)
          results = Rbac.search(:class => "ExtManagementSystem", :results_format => :objects, :miq_group => owner_group).first
          expect(results).to match_array []
        end
      end

      context "with accessible_tenant_ids filtering (strategy = nil aka tenant only)" do
        it "can see tenant's request task" do
          task = FactoryGirl.create(:miq_request_task, :tenant => owner_tenant)
          results = Rbac.search(:class => "MiqRequestTask", :results_format => :objects, :miq_group => owner_group).first
          expect(results).to match_array [task]
        end

        it "can't see parent tenant's request task" do
          _task = FactoryGirl.create(:miq_request_task, :tenant => owner_tenant)
          results = Rbac.search(:class => "MiqRequestTask", :results_format => :objects, :miq_group => child_group).first
          expect(results).to match_array []
        end

        it "can't see descendant tenant's request task" do
          _task = FactoryGirl.create(:miq_request_task, :tenant => child_tenant)
          results = Rbac.search(:class => "MiqRequestTask", :results_format => :objects, :miq_group => owner_group).first
          expect(results).to match_array []
        end
      end

      context "tenant access strategy VMs and Templates" do
        let(:owned_template) { FactoryGirl.create(:template_vmware, :tenant => owner_tenant) }
        let(:child_tenant)   { FactoryGirl.create(:tenant, :divisible => false, :parent => owner_tenant) }
        let(:child_group)    { FactoryGirl.create(:miq_group, :tenant => child_tenant) }

        context "searching MiqTemplate" do
          it "can't see descendant tenant's templates" do
            owned_template.update_attributes!(:tenant_id => child_tenant.id, :miq_group_id => child_group.id)
            results, = Rbac.search(:class => "MiqTemplate", :results_format => :objects, :miq_group_id => owner_group.id)
            expect(results).to match_array []
          end

          it "can see ancestor tenant's templates" do
            owned_template.update_attributes!(:tenant_id => owner_tenant.id, :miq_group_id => owner_tenant.id)
            results, = Rbac.search(:class => "MiqTemplate", :results_format => :objects, :miq_group_id => child_group.id)
            expect(results).to match_array [owned_template]
          end
        end

        context "searching VmOrTemplate" do
          let(:child_child_tenant) { FactoryGirl.create(:tenant, :divisible => false, :parent => child_tenant) }
          let(:child_child_group)  { FactoryGirl.create(:miq_group, :tenant => child_child_tenant) }

          it "can't see descendant tenant's templates but can see descendant tenant's VMs" do
            owned_template.update_attributes!(:tenant_id => child_child_tenant.id, :miq_group_id => child_child_group.id)
            owned_vm.update_attributes(:tenant_id => child_child_tenant.id, :miq_group_id => child_child_group.id)
            results, = Rbac.search(:class => "VmOrTemplate", :results_format => :objects, :miq_group_id => child_group.id)
            expect(results).to match_array [owned_vm]
          end

          it "can see ancestor tenant's templates but can't see ancestor tenant's VMs" do
            owned_template.update_attributes!(:tenant_id => owner_tenant.id, :miq_group_id => owner_group.id)
            results, = Rbac.search(:class => "VmOrTemplate", :results_format => :objects, :miq_group_id => child_group.id)
            expect(results).to match_array [owned_template]
          end

          it "can see ancestor tenant's templates and descendant tenant's VMs" do
            owned_template.update_attributes!(:tenant_id => owner_tenant.id, :miq_group_id => owner_group.id)
            owned_vm.update_attributes(:tenant_id => child_child_tenant.id, :miq_group_id => child_child_group.id)
            results, = Rbac.search(:class => "VmOrTemplate", :results_format => :objects, :miq_group_id => child_group.id)
            expect(results).to match_array [owned_template, owned_vm]
          end

          it "can't see descendant tenant's templates nor ancestor tenant's VMs" do
            owned_template.update_attributes!(:tenant_id => child_child_tenant.id, :miq_group_id => child_child_group.id)
            owned_vm.update_attributes(:tenant_id => owner_tenant.id, :miq_group_id => owner_group.id)
            results, = Rbac.search(:class => "VmOrTemplate", :results_format => :objects, :miq_group_id => child_group.id)
            expect(results).to match_array []
          end
        end
      end

      context "tenant 0" do
        it "can see requests owned by any tenants" do
          request_task = FactoryGirl.create(:miq_request_task, :tenant => owner_tenant)
          t0_group = FactoryGirl.create(:miq_group, :tenant => default_tenant)
          results = Rbac.search(:class => "MiqRequestTask", :results_format => :objects, :miq_group => t0_group).first
          expect(results).to match_array [request_task]
        end
      end
    end

    context "searching for hosts" do
      it "can filter results by vmm_vendor" do
        host = FactoryGirl.create(:host, :vmm_vendor => "vmware")
        expression = MiqExpression.new("=" => {"field" => "Host-vmm_vendor", "value" => "vmware"})

        results = Rbac.search(:class => "Host", :filter => expression).first

        expect(results).to include(host.id)
      end
    end

    context "searching for vms" do
      it "can filter results by vendor" do
        vm = FactoryGirl.create(:vm_vmware, :vendor => "vmware")
        expression = MiqExpression.new("=" => {"field" => "Vm-vendor", "value" => "vmware"})

        results = Rbac.search(:class => "Vm", :filter => expression).first

        expect(results).to include(vm.id)
      end
    end
  end

  context "common setup" do
    let(:group) { FactoryGirl.create(:miq_group) }
    let(:user) { FactoryGirl.create(:user, :miq_groups => [group]) }

    before(:each) do
      @tags = {
        2 => "/managed/environment/prod",
        3 => "/managed/environment/dev",
        4 => "/managed/service_level/gold",
        5 => "/managed/service_level/silver"
      }
    end

    context "with User and Group" do
      def get_rbac_results_for_and_expect_objects(klass, expected_objects)
        User.current_user = user

        results = Rbac.search(:class => klass, :results_format => :objects).first
        expect(results).to match_array(expected_objects)
      end

      it "returns all users" do
        get_rbac_results_for_and_expect_objects(User, [user, other_user])
      end

      it "returns all groups" do
        _expected_groups = [group, other_group] # this will create more groups than 2
        get_rbac_results_for_and_expect_objects(MiqGroup, MiqGroup.all)
      end

      context "with self-service user" do
        before(:each) do
          allow_any_instance_of(User).to receive_messages(:self_service? => true)
        end

        it "returns only the current user" do
          get_rbac_results_for_and_expect_objects(User, [user])
        end

        it "returns only the current group" do
          get_rbac_results_for_and_expect_objects(MiqGroup, [user.current_group])
        end
      end
    end

    context "with Hosts" do
      let(:hosts) { [@host1, @host2] }
      before(:each) do
        @host1 = FactoryGirl.create(:host, :name => "Host1", :hostname => "host1.local")
        @host2 = FactoryGirl.create(:host, :name => "Host2", :hostname => "host2.local")
      end

      context "having Metric data" do
        before(:each) do
          @timestamps = [
            ["2010-04-14T20:52:30Z", 100.0],
            ["2010-04-14T21:51:10Z", 1.0],
            ["2010-04-14T21:51:30Z", 2.0],
            ["2010-04-14T21:51:50Z", 4.0],
            ["2010-04-14T21:52:10Z", 8.0],
            ["2010-04-14T21:52:30Z", 15.0],
            ["2010-04-14T22:52:30Z", 100.0],
          ]
          @timestamps.each do |t, v|
            [@host1, @host2].each do |h|
              h.metric_rollups << FactoryGirl.create(:metric_rollup_host_hr,
                                                     :timestamp                  => t,
                                                     :cpu_usage_rate_average     => v,
                                                     :cpu_ready_delta_summation  => v * 1000, # Multiply by a factor of 1000 to maake it more realistic and enable testing virtual col v_pct_cpu_ready_delta_summation
                                                     :sys_uptime_absolute_latest => v
                                                    )
            end
          end
        end

        context "with only managed filters" do
          before(:each) do
            group.update_attributes(:filters => {"managed" => [["/managed/environment/prod"], ["/managed/service_level/silver"]], "belongsto" => []})

            @tags = ["/managed/environment/prod"]
            @host2.tag_with(@tags.join(' '), :ns => '*')
            @tags << "/managed/service_level/silver"
          end

          it ".search finds the right HostPerformance rows" do
            @host1.tag_with(@tags.join(' '), :ns => '*')
            results, attrs = Rbac.search(:class => "HostPerformance", :user => user, :results_format => :objects)
            expect(attrs[:user_filters]).to eq(group.filters)
            expect(attrs[:total_count]).to eq(@timestamps.length * hosts.length)
            expect(attrs[:auth_count]).to eq(@timestamps.length)
            expect(results.length).to eq(@timestamps.length)
            results.each { |vp| expect(vp.resource).to eq(@host1) }
          end

          it ".search filters out the wrong HostPerformance rows with :match_via_descendants option" do
            @vm = FactoryGirl.create(:vm_vmware, :name => "VM1", :host => @host2)
            @vm.tag_with(@tags.join(' '), :ns => '*')
            results, attrs = Rbac.search(:targets => HostPerformance, :class => "HostPerformance", :user => user, :results_format => :objects, :match_via_descendants => {"VmOrTemplate" => :host})
            expect(attrs[:user_filters]).to eq(group.filters)
            expect(attrs[:total_count]).to eq(@timestamps.length * hosts.length)
            expect(attrs[:auth_count]).to eq(@timestamps.length)
            expect(results.length).to eq(@timestamps.length)
            results.each { |vp| expect(vp.resource).to eq(@host2) }

            results, attrs = Rbac.search(:targets => HostPerformance, :class => "HostPerformance", :user => user, :results_format => :objects, :match_via_descendants => "Vm")
            expect(attrs[:user_filters]).to eq(group.filters)
            expect(attrs[:total_count]).to eq(@timestamps.length * hosts.length)
            expect(attrs[:auth_count]).to eq(@timestamps.length)
            expect(results.length).to eq(@timestamps.length)
            results.each { |vp| expect(vp.resource).to eq(@host2) }
          end

          it ".search filters out the wrong HostPerformance rows" do
            @host1.tag_with(@tags.join(' '), :ns => '*')
            results, attrs = Rbac.search(:targets => HostPerformance.all, :class => "HostPerformance", :user => user, :results_format => :objects)
            expect(attrs[:user_filters]).to eq(group.filters)
            expect(attrs[:total_count]).to eq(@timestamps.length * hosts.length)
            expect(attrs[:auth_count]).to eq(@timestamps.length)
            expect(results.length).to eq(@timestamps.length)
            results.each { |vp| expect(vp.resource).to eq(@host1) }
          end
        end

        context "with only belongsto filters" do
          before(:each) do
            group.update_attributes(:filters => {"managed" => [], "belongsto" => ["/belongsto/ExtManagementSystem|ems1"]})

            ems1 = FactoryGirl.create(:ems_vmware, :name => 'ems1')
            @host1.update_attributes(:ext_management_system => ems1)
            @host2.update_attributes(:ext_management_system => ems1)

            root = FactoryGirl.create(:ems_folder, :name => "Datacenters")
            root.parent = ems1
            dc = FactoryGirl.create(:ems_folder, :name => "Datacenter1")
            dc.parent = root
            hfolder   = FactoryGirl.create(:ems_folder, :name => "Hosts")
            hfolder.parent = dc
            @host1.parent = hfolder
          end

          it ".search finds the right HostPerformance rows" do
            results, attrs = Rbac.search(:class => "HostPerformance", :user => user, :results_format => :objects)
            expect(attrs[:user_filters]).to eq(group.filters)
            expect(attrs[:total_count]).to eq(@timestamps.length * hosts.length)
            expect(attrs[:auth_count]).to eq(@timestamps.length)
            expect(results.length).to eq(@timestamps.length)
            results.each { |vp| expect(vp.resource).to eq(@host1) }
          end

          it ".search filters out the wrong HostPerformance rows" do
            results, attrs = Rbac.search(:targets => HostPerformance.all, :class => "HostPerformance", :user => user, :results_format => :objects)
            expect(attrs[:user_filters]).to eq(group.filters)
            expect(attrs[:total_count]).to eq(@timestamps.length * hosts.length)
            expect(attrs[:auth_count]).to eq(@timestamps.length)
            expect(results.length).to eq(@timestamps.length)
            results.each { |vp| expect(vp.resource).to eq(@host1) }
          end
        end
      end

      context "with VMs and Templates" do
        before(:each) do
          @ems = FactoryGirl.create(:ems_vmware, :name => 'ems1')
          @host1.update_attributes(:ext_management_system => @ems)
          @host2.update_attributes(:ext_management_system => @ems)

          root            = FactoryGirl.create(:ems_folder, :name => "Datacenters")
          root.parent     = @ems
          dc              = FactoryGirl.create(:ems_folder, :name => "Datacenter1", :is_datacenter => true)
          dc.parent       = root
          hfolder         = FactoryGirl.create(:ems_folder, :name => "host")
          hfolder.parent  = dc
          @vfolder        = FactoryGirl.create(:ems_folder, :name => "vm")
          @vfolder.parent = dc
          @host1.parent   = hfolder
          @vm_folder_path = "/belongsto/ExtManagementSystem|#{@ems.name}/EmsFolder|#{root.name}/EmsFolder|#{dc.name}/EmsFolder|#{@vfolder.name}"

          @vm       = FactoryGirl.create(:vm_vmware,       :name => "VM1",       :host => @host1, :ext_management_system => @ems)
          @template = FactoryGirl.create(:template_vmware, :name => "Template1", :host => @host1, :ext_management_system => @ems)
        end

        it "honors ems_id conditions" do
          results = Rbac.search(:class => "ManageIQ::Providers::Vmware::InfraManager::Template", :conditions => ["ems_id IS NULL"], :results_format => :objects)
          objects = results.first
          expect(objects).to eq([])

          @template.update_attributes(:ext_management_system => nil)
          results = Rbac.search(:class => "ManageIQ::Providers::Vmware::InfraManager::Template", :conditions => ["ems_id IS NULL"], :results_format => :objects)
          objects = results.first
          expect(objects).to eq([@template])
        end

        context "search on EMSes" do
          before(:each) do
            @ems2 = FactoryGirl.create(:ems_vmware, :name => 'ems2')
          end

          it "preserves order of targets" do
            @ems3 = FactoryGirl.create(:ems_vmware, :name => 'ems3')
            @ems4 = FactoryGirl.create(:ems_vmware, :name => 'ems4')

            targets = [@ems2, @ems4, @ems3, @ems]

            results = Rbac.search(:targets => targets, :results_format => :objects, :user => user)
            objects = results.first
            expect(objects.length).to eq(4)
            expect(objects).to eq(targets)
          end

          it "finds both EMSes without belongsto filters" do
            results = Rbac.search(:class => "ExtManagementSystem", :results_format => :objects, :user => user)
            objects = results.first
            expect(objects.length).to eq(2)
          end

          it "finds one EMS with belongsto filters" do
            group.update_attributes(:filters => {"managed" => [], "belongsto" => [@vm_folder_path]})
            results = Rbac.search(:class => "ExtManagementSystem", :results_format => :objects, :user => user)
            objects = results.first
            expect(objects).to eq([@ems])
          end
        end

        it "search on VMs and Templates should return no objects if self-service user" do
          allow_any_instance_of(User).to receive_messages(:self_service? => true)
          User.with_user(user) do
            results = Rbac.search(:class => "VmOrTemplate", :results_format => :objects)
            objects = results.first
            expect(objects.length).to eq(0)
          end
        end

        it "search on VMs and Templates should return both objects" do
          results = Rbac.search(:class => "VmOrTemplate", :results_format => :objects)
          objects = results.first
          expect(objects.length).to eq(2)
          expect(objects).to match_array([@vm, @template])

          group.update_attributes(:filters => {"managed" => [], "belongsto" => [@vm_folder_path]})
          results = Rbac.search(:class => "VmOrTemplate", :results_format => :objects, :user => user)
          objects = results.first
          expect(objects.length).to eq(0)

          [@vm, @template].each do |v|
            v.with_relationship_type("ems_metadata") { v.parent = @vfolder }
            v.save
          end

          group.update_attributes(:filters => {"managed" => [], "belongsto" => [@vm_folder_path]})
          results = Rbac.search(:class => "VmOrTemplate", :results_format => :objects, :user => user)
          objects = results.first
          expect(objects.length).to eq(2)
          expect(objects).to match_array([@vm, @template])
        end

        it "search on VMs should return a single object" do
          results = Rbac.search(:class => "Vm", :results_format => :objects)
          objects = results.first
          expect(objects.length).to eq(1)
          expect(objects).to match_array([@vm])

          group.update_attributes(:filters => {"managed" => [], "belongsto" => [@vm_folder_path]})

          results = Rbac.search(:class => "Vm", :results_format => :objects, :user => user)
          objects = results.first
          expect(objects.length).to eq(0)

          [@vm, @template].each do |v|
            v.with_relationship_type("ems_metadata") { v.parent = @vfolder }
            v.save
          end

          group.update_attributes(:filters => {"managed" => [], "belongsto" => [@vm_folder_path]})
          results = Rbac.search(:class => "Vm", :results_format => :objects, :user => user)
          objects = results.first
          expect(objects.length).to eq(1)
          expect(objects).to match_array([@vm])
        end

        it "search on Templates should return a single object" do
          results = Rbac.search(:class => "MiqTemplate", :results_format => :objects)
          objects = results.first
          expect(objects.length).to eq(1)
          expect(objects).to match_array([@template])

          group.update_attributes(:filters => {"managed" => [], "belongsto" => [@vm_folder_path]})

          results = Rbac.search(:class => "MiqTemplate", :results_format => :objects, :user => user)
          objects = results.first
          expect(objects.length).to eq(0)

          [@vm, @template].each do |v|
            v.with_relationship_type("ems_metadata") { v.parent = @vfolder }
            v.save
          end

          group.update_attributes(:filters => {"managed" => [], "belongsto" => [@vm_folder_path]})
          results = Rbac.search(:class => "MiqTemplate", :results_format => :objects, :user => user)
          objects = results.first
          expect(objects.length).to eq(1)
          expect(objects).to match_array([@template])
        end
      end

      context "when applying a filter to the host and it's cluster (FB17114)" do
        before(:each) do
          @ems = FactoryGirl.create(:ems_vmware, :name => 'ems')
          @ems_folder_path = "/belongsto/ExtManagementSystem|#{@ems.name}"
          @root = FactoryGirl.create(:ems_folder, :name => "Datacenters")
          @root.parent = @ems
          @mtc = FactoryGirl.create(:ems_folder, :name => "MTC", :is_datacenter => true)
          @mtc.parent = @root
          @mtc_folder_path = "/belongsto/ExtManagementSystem|#{@ems.name}/EmsFolder|#{@root.name}/EmsFolder|#{@mtc.name}"

          @hfolder         = FactoryGirl.create(:ems_folder, :name => "host")
          @hfolder.parent  = @mtc

          @cluster = FactoryGirl.create(:ems_cluster, :name => "MTC Development")
          @cluster.parent = @hfolder
          @cluster_folder_path = "#{@mtc_folder_path}/EmsFolder|#{@hfolder.name}/EmsCluster|#{@cluster.name}"

          @rp = FactoryGirl.create(:resource_pool, :name => "Default for MTC Development")
          @rp.parent = @cluster

          @host_1 = FactoryGirl.create(:host, :name => "Host_1", :ems_cluster => @cluster, :ext_management_system => @ems)
          @host_2 = FactoryGirl.create(:host, :name => "Host_2", :ext_management_system => @ems)

          @vm1 = FactoryGirl.create(:vm_vmware, :name => "VM1", :host => @host_1, :ext_management_system => @ems)
          @vm2 = FactoryGirl.create(:vm_vmware, :name => "VM2", :host => @host_2, :ext_management_system => @ems)

          @template1 = FactoryGirl.create(:template_vmware, :name => "Template1", :host => @host_1, :ext_management_system => @ems)
          @template2 = FactoryGirl.create(:template_vmware, :name => "Template2", :host => @host_2, :ext_management_system => @ems)
        end

        it "returns all host's VMs and templates when host filter is set up" do
          @host_1.parent = @hfolder # add host to folder's hierarchy
          mtc_folder_path_with_host = "#{@mtc_folder_path}/EmsFolder|host/Host|#{@host_1.name}"
          group.update_attributes(:filters => {"managed" => [], "belongsto" => [mtc_folder_path_with_host]})

          ["ManageIQ::Providers::Vmware::InfraManager::Vm", "Vm"].each do |klass|
            results2 = Rbac.search(:class => klass, :user => user, :results_format => :objects).first
            expect(results2.length).to eq(1)
          end

          results2 = Rbac.search(:class => "VmOrTemplate", :user => user, :results_format => :objects).first
          expect(results2.length).to eq(2)

          ["ManageIQ::Providers::Vmware::InfraManager::Template", "MiqTemplate"].each do |klass|
            results2 = Rbac.search(:class => klass, :user => user, :results_format => :objects).first
            expect(results2.length).to eq(1)
          end
        end

        it "get all the descendants without belongsto filter" do
          results, attrs = Rbac.search(:class => "Host", :user => user, :results_format => :objects)
          expect(results.length).to eq(4)
          expect(attrs[:total_count]).to eq(4)
          expect(attrs[:auth_count]).to eq(4)
          expect(attrs[:user_filters]).to eq({"managed" => [], "belongsto" => []})

          results2 = Rbac.search(:class => "Vm", :user => user, :results_format => :objects).first
          expect(results2.length).to eq(2)

          results3 = Rbac.search(:class => "VmOrTemplate", :user => user, :results_format => :objects).first
          expect(results3.length).to eq(4)
        end

        it "get all the vm or templates with belongsto filter" do
          group.update_attributes(:filters => {"managed" => [], "belongsto" => [@cluster_folder_path]})
          results, attrs = Rbac.search(:class => "VmOrTemplate", :user => user, :results_format => :objects)
          expect(results.length).to eq(0)
          expect(attrs[:total_count]).to eq(4)
          expect(attrs[:auth_count]).to eq(0)

          [@vm1, @template1].each do |v|
            v.with_relationship_type("ems_metadata") { v.parent = @rp }
            v.save
          end
          group.update_attributes(:filters => {"managed" => [], "belongsto" => [@cluster_folder_path]})

          results2, attrs = Rbac.search(:class => "VmOrTemplate", :user => user, :results_format => :objects)
          expect(attrs[:user_filters]).to eq({"managed" => [], "belongsto" => [@cluster_folder_path]})
          expect(attrs[:total_count]).to eq(4)
          expect(attrs[:auth_count]).to eq(2)
          expect(results2.length).to eq(2)
        end

        it "get all the hosts with belongsto filter" do
          group.update_attributes(:filters => {"managed" => [], "belongsto" => [@cluster_folder_path]})
          results, attrs = Rbac.search(:class => "Host", :user => user, :results_format => :objects)
          expect(attrs[:user_filters]).to eq({"managed" => [], "belongsto" => [@cluster_folder_path]})
          expect(attrs[:total_count]).to eq(4)
          expect(attrs[:auth_count]).to eq(1)
          expect(results.length).to eq(1)

          group.update_attributes(:filters => {"managed" => [], "belongsto" => [@mtc_folder_path]})
          results2, attrs = Rbac.search(:class => "Host", :user => user, :results_format => :objects)
          expect(attrs[:user_filters]).to eq({"managed" => [], "belongsto" => [@mtc_folder_path]})
          expect(attrs[:total_count]).to eq(4)
          expect(attrs[:auth_count]).to eq(1)
          expect(results2.length).to eq(1)

          group.update_attributes(:filters => {"managed" => [], "belongsto" => [@ems_folder_path]})
          results3, attrs = Rbac.search(:class => "Host", :user => user, :results_format => :objects)
          expect(attrs[:user_filters]).to eq({"managed" => [], "belongsto" => [@ems_folder_path]})
          expect(attrs[:total_count]).to eq(4)
          expect(attrs[:auth_count]).to eq(1)
          expect(results3.length).to eq(1)
        end
      end
    end

    context "with services" do
      before(:each) do
        @service1 = FactoryGirl.create(:service)
        @service2 = FactoryGirl.create(:service)
        @service3 = FactoryGirl.create(:service, :evm_owner => user)
        @service4 = FactoryGirl.create(:service, :miq_group => group)
        @service5 = FactoryGirl.create(:service, :evm_owner => user, :miq_group => group)
      end

      context ".search" do
        it "self-service group" do
          allow_any_instance_of(MiqGroup).to receive_messages(:self_service? => true)

          results = Rbac.search(:class => "Service", :results_format => :objects, :miq_group => user.current_group).first
          expect(results.to_a).to match_array([@service4, @service5])
        end

        context "with self-service user" do
          before(:each) do
            allow_any_instance_of(User).to receive_messages(:self_service? => true)
          end

          it "works when targets are empty" do
            User.with_user(user) do
              results = Rbac.search(:class => "Service", :results_format => :objects).first
              expect(results.to_a).to match_array([@service3, @service4, @service5])
            end
          end
        end

        it "limited self-service group" do
          allow_any_instance_of(MiqGroup).to receive_messages(:self_service? => true)
          allow_any_instance_of(MiqGroup).to receive_messages(:limited_self_service? => true)

          results = Rbac.search(:class => "Service", :results_format => :objects, :miq_group => user.current_group).first
          expect(results.to_a).to match_array([@service4, @service5])
        end

        context "with limited self-service user" do
          before(:each) do
            allow_any_instance_of(User).to receive_messages(:self_service? => true)
            allow_any_instance_of(User).to receive_messages(:limited_self_service? => true)
          end

          it "works when targets are empty" do
            User.with_user(user) do
              results = Rbac.search(:class => "Service", :results_format => :objects).first
              expect(results.to_a).to match_array([@service3, @service5])
            end
          end
        end

        it "works when targets are a list of ids" do
          results = Rbac.search(:targets => Service.all.collect(&:id), :class => "Service", :results_format => :objects).first
          expect(results.length).to eq(5)
          expect(results.first).to be_kind_of(Service)

          results = Rbac.search(:targets => Service.all.collect(&:id), :class => "Service", :results_format => :ids).first
          expect(results.length).to eq(5)
          expect(results.first).to be_kind_of(Integer)
        end

        it "works when targets are empty" do
          results = Rbac.search(:class => "Service", :results_format => :objects).first
          expect(results.length).to eq(5)
        end
      end
    end

    context "with tagged VMs" do
      before(:each) do
        [
          FactoryGirl.create(:host, :name => "Host1", :hostname => "host1.local"),
          FactoryGirl.create(:host, :name => "Host2", :hostname => "host2.local"),
          FactoryGirl.create(:host, :name => "Host3", :hostname => "host3.local"),
          FactoryGirl.create(:host, :name => "Host4", :hostname => "host4.local")
        ].each_with_index do |host, i|
          grp = i + 1
          guest_os = %w(_none_ windows ubuntu windows ubuntu)[grp]
          vm = FactoryGirl.build(:vm_vmware, :name => "Test Group #{grp} VM #{i}")
          vm.hardware = FactoryGirl.build(:hardware, :cpu_sockets => (grp * 2), :memory_mb => (grp * 1.megabytes), :guest_os => guest_os)
          vm.host = host
          vm.evm_owner_id = user.id  if i.even?
          vm.miq_group_id = group.id if i.odd?
          vm.save
          vm.tag_with(@tags.values.join(" "), :ns => "*") if i > 0
        end

        Vm.scope :group_scope, ->(group_num) { Vm.where("name LIKE ?", "Test Group #{group_num}%") }
      end

      context ".search" do
        it "self-service group" do
          allow_any_instance_of(MiqGroup).to receive_messages(:self_service? => true)

          results = Rbac.search(:class => "Vm", :results_format => :objects, :miq_group => user.current_group).first
          expect(results.length).to eq(2)
        end

        context "with self-service user" do
          before(:each) do
            allow_any_instance_of(User).to receive_messages(:self_service? => true)
          end

          it "works when targets are empty" do
            User.with_user(user) do
              results = Rbac.search(:class => "Vm", :results_format => :objects).first
              expect(results.length).to eq(4)
            end
          end

          it "works when passing a named_scope" do
            User.with_user(user) do
              results = Rbac.search(:class => "Vm", :results_format => :objects, :named_scope => [:group_scope, 1]).first
              expect(results.length).to eq(1)
            end
          end
        end

        it "limited self-service group" do
          allow_any_instance_of(MiqGroup).to receive_messages(:self_service? => true)
          allow_any_instance_of(MiqGroup).to receive_messages(:limited_self_service? => true)

          results = Rbac.search(:class => "Vm", :results_format => :objects, :miq_group => user.current_group).first
          expect(results.length).to eq(2)
        end

        context "with limited self-service user" do
          before(:each) do
            allow_any_instance_of(User).to receive_messages(:self_service? => true)
            allow_any_instance_of(User).to receive_messages(:limited_self_service? => true)
          end

          it "works when targets are empty" do
            User.with_user(user) do
              results = Rbac.search(:class => "Vm", :results_format => :objects).first
              expect(results.length).to eq(2)
            end
          end

          it "works when passing a named_scope" do
            User.with_user(user) do
              results = Rbac.search(:class => "Vm", :results_format => :objects, :named_scope => [:group_scope, 1]).first
              expect(results.length).to eq(1)

              results = Rbac.search(:class => "Vm", :results_format => :objects, :named_scope => [:group_scope, 2]).first
              expect(results.length).to eq(0)
            end
          end
        end

        it "works when targets are a list of ids" do
          results = Rbac.search(:targets => Vm.all.collect(&:id), :class => "Vm", :results_format => :objects).first
          expect(results.length).to eq(4)
          expect(results.first).to be_kind_of(Vm)

          results = Rbac.search(:targets => Vm.all.collect(&:id), :class => "Vm", :results_format => :ids).first
          expect(results.length).to eq(4)
          expect(results.first).to be_kind_of(Integer)
        end

        it "works when targets are empty" do
          results = Rbac.search(:class => "Vm", :results_format => :objects).first
          expect(results.length).to eq(4)
        end

        it "works when targets is a class" do
          results = Rbac.search(:targets => Vm, :results_format => :objects).first
          expect(results.length).to eq(4)
        end

        it "works when passing a named_scope" do
          results = Rbac.search(:class => "Vm", :results_format => :objects, :named_scope => [:group_scope, 4]).first
          expect(results.length).to eq(1)
        end

        it "works when targets are a named scope" do
          results = Rbac.search(:targets => Vm.group_scope(4), :results_format => :objects).first
          expect(results.length).to eq(1)
        end

        it "works when the filter is not fully supported in SQL (FB11080)" do
          filter = '--- !ruby/object:MiqExpression
          exp:
            or:
            - STARTS WITH:
                value: Test Group 1
                field: Vm-name
            - "=":
                value: Host2
                field: Vm-host_name
          '
          results = Rbac.search(:class => "Vm", :filter => YAML.load(filter), :results_format => :objects).first
          expect(results.length).to eq(2)
        end
      end

      context "with only managed filters (FB9153, FB11442)" do
        before(:each) do
          group.update_attributes(:filters => {"managed" => [["/managed/environment/prod"], ["/managed/service_level/silver"]], "belongsto" => []})
        end

        context ".search" do
          it "does not raise any errors when user filters are passed and search expression contains columns in a sub-table" do
            exp = YAML.load("--- !ruby/object:MiqExpression
            exp:
              and:
              - IS NOT EMPTY:
                  field: Vm.host-name
              - IS NOT EMPTY:
                  field: Vm-name
            ")
            expect { Rbac.search(:class => "Vm", :filter => exp, :user => user, :results_format => :objects, :order => "vms.name desc") }.not_to raise_error
          end

          it "works when limit, offset and user filters are passed and search expression contains columns in a sub-table" do
            exp = YAML.load("--- !ruby/object:MiqExpression
            exp:
              and:
              - IS NOT EMPTY:
                  field: Vm.host-name
              - IS NOT EMPTY:
                  field: Vm-name
            ")
            results, attrs = Rbac.search(:class => "Vm", :filter => exp, :user => user, :results_format => :objects, :limit => 2, :offset => 2, :order => "vms.name desc")
            expect(results.length).to eq(1)
            expect(results.first.name).to eq("Test Group 2 VM 1")
            expect(attrs[:auth_count]).to eq(3)
            expect(attrs[:total_count]).to eq(4)
          end

          it "works when class does not participate in RBAC and user filters are passed" do
            2.times do |i|
              FactoryGirl.create(:ems_event, :timestamp => Time.now.utc, :message => "Event #{i}")
            end

            report = MiqReport.new(:db => "EmsEvent")
            exp = YAML.load '--- !ruby/object:MiqExpression
            exp:
              IS:
                field: EmsEvent-timestamp
                value: Today
            '

            results, attrs = Rbac.search(:class => "EmsEvent", :filter => exp, :user => user, :results_format => :objects)

            expect(results.length).to eq(2)
            expect(attrs[:auth_count]).to eq(2)
            expect(attrs[:user_filters]["managed"]).to eq(group.filters['managed'])
            expect(attrs[:total_count]).to eq(2)
          end
        end
      end
    end

    context "Evaluating date/time expressions" do
      before(:each) do
        Timecop.freeze("2011-01-11 17:30 UTC")

        user.settings = {:display => {:timezone => "Eastern Time (US & Canada)"}}
        user.save
        @host1 = FactoryGirl.create(:host)
        @host2 = FactoryGirl.create(:host)

        # VMs hours apart
        (0...20).each do |i|
          FactoryGirl.create(:vm_vmware, :name => "VM Hour #{i}", :last_scan_on => i.hours.ago.utc, :retires_on => i.hours.ago.utc.to_date, :host => @host1)
        end

        # VMs days apart
        (0...15).each do |i|
          FactoryGirl.create(:vm_vmware, :name => "VM Day #{i}", :last_scan_on => i.days.ago.utc, :retires_on => i.days.ago.utc.to_date, :host => @host2)
        end

        # VMs weeks apart
        (0...10).each do |i|
          FactoryGirl.create(:vm_vmware, :name => "VM Week #{i}", :last_scan_on => i.weeks.ago.utc, :retires_on => i.weeks.ago.utc.to_date, :host => @host2)
        end

        # VMs months apart
        (0...10).each do |i|
          FactoryGirl.create(:vm_vmware, :name => "VM Month #{i}", :last_scan_on => i.months.ago.utc, :retires_on => i.months.ago.utc.to_date, :host => @host2)
        end

        # VMs quarters apart
        (0...5).each do |i|
          FactoryGirl.create(:vm_vmware, :name => "VM Quarter #{i}", :last_scan_on => (i * 3).months.ago.utc, :retires_on => (i * 3).months.ago.utc.to_date, :host => @host2)
        end

        # VMs with nil dates/times
        (0...2).each do |i|
          FactoryGirl.create(:vm_vmware, :name => "VM Quarter #{i}", :host => @host2)
        end
      end

      after(:each) do
        Timecop.return
      end

      it "should return the correct results when searching with a date/time filter" do
        # Vm.all(:order => "last_scan_on").each {|v| puts " #{v.last_scan_on ? v.last_scan_on.iso8601 : "nil"} => #{v.name} -> #{v.host_id}"}

        # Test >, <, >=, <=
        result = Rbac.search(:class => "Vm", :filter => MiqExpression.new("AFTER" => {"field" => "Vm-last_scan_on", "value" => "2011-01-11 9:00"})).first
        expect(result.length).to eq(13)

        result = Rbac.search(:class => "Vm", :filter => MiqExpression.new(">" => {"field" => "Vm-last_scan_on", "value" => "2011-01-11 9:00"})).first
        expect(result.length).to eq(13)

        # Test IS EMPTY and IS NOT EMPTY
        result = Rbac.search(:class => "Vm", :filter => MiqExpression.new("IS EMPTY" => {"field" => "Vm-last_scan_on"})).first
        expect(result.length).to eq(2)

        result = Rbac.search(:class => "Vm", :filter => MiqExpression.new("IS EMPTY" => {"field" => "Vm-retires_on"})).first
        expect(result.length).to eq(2)

        result = Rbac.search(:class => "Vm", :filter => MiqExpression.new("IS NOT EMPTY" => {"field" => "Vm-last_scan_on"})).first
        expect(result.length).to eq(60)

        result = Rbac.search(:class => "Vm", :filter => MiqExpression.new("IS NOT EMPTY" => {"field" => "Vm-retires_on"})).first
        expect(result.length).to eq(60)

        # Test IS
        result = Rbac.search(:class => "Vm", :filter => MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})).first
        expect(result.length).to eq(3)

        result = Rbac.search(:class => "Vm", :filter => MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "2011-01-11"})).first
        expect(result.length).to eq(22)

        result = Rbac.search(:class => "Vm", :filter => MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "Today"})).first
        expect(result.length).to eq(22)

        result = Rbac.search(:class => "Vm", :filter => MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "3 Hours Ago"})).first
        expect(result.length).to eq(1)

        result = Rbac.search(:class => "Vm", :filter => MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "3 Hours Ago"})).first
        expect(result.length).to eq(22)

        result = Rbac.search(:class => "Vm", :filter => MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "Last Month"})).first
        expect(result.length).to eq(9)

        # Test FROM
        result = Rbac.search(:class  => "Vm",
                             :filter => MiqExpression.new(
                               "FROM" => {"field" => "Vm-last_scan_on", "value" => ["2010-07-11", "2010-12-31"]}
                             )).first
        expect(result.length).to eq(20)

        result = Rbac.search(:class  => "Vm",
                             :filter => MiqExpression.new(
                               "FROM" => {"field" => "Vm-retires_on", "value" => ["2010-07-11", "2010-12-31"]}
                             )).first
        expect(result.length).to eq(20)

        result = Rbac.search(:class  => "Vm",
                             :filter => MiqExpression.new(
                               "FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-09 17:00", "2011-01-10 23:30:59"]}
                             )).first
        expect(result.length).to eq(4)

        result = Rbac.search(:class => "Vm", :filter => MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["Last Week", "Last Week"]})).first
        expect(result.length).to eq(8)

        result = Rbac.search(:class => "Vm", :filter => MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Week", "Last Week"]})).first
        expect(result.length).to eq(8)

        result = Rbac.search(:class => "Vm", :filter => MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Week", "This Week"]})).first
        expect(result.length).to eq(33)

        result = Rbac.search(:class => "Vm", :filter => MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2 Months Ago", "1 Month Ago"]})).first
        expect(result.length).to eq(14)

        result = Rbac.search(:class => "Vm", :filter => MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Month", "Last Month"]})).first
        expect(result.length).to eq(9)

        # Inside a find/check expression
        result = Rbac.search(:class => "Host", :filter => MiqExpression.new(
          "FIND" => {
            "checkany" => {"FROM" => {"field" => "Host.vms-last_scan_on", "value" => ["2011-01-08 17:00", "2011-01-09 23:30:59"]}},
            "search"   => {"IS NOT NULL" => {"field" => "Host.vms-name"}}}
        )).first
        expect(result.length).to eq(1)

        result = Rbac.search(:class => "Host", :filter => MiqExpression.new(
          "FIND" => {
            "search"   => {"FROM" => {"field" => "Host.vms-last_scan_on", "value" => ["2011-01-08 17:00", "2011-01-09 23:30:59"]}},
            "checkall" => {"IS NOT NULL" => {"field" => "Host.vms-name"}}}
        )).first
        expect(result.length).to eq(1)

        # Test FROM with time zone
        result = Rbac.search(:class  => "Vm",
                             :user   => user,
                             :filter => MiqExpression.new(
                               "FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-09 17:00", "2011-01-10 23:30:59"]}
                             )).first
        expect(result.length).to eq(8)

        # Test IS with time zone
        result = Rbac.search(:class  => "Vm",
                             :user   => user,
                             :filter => MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
                            ).first
        expect(result.length).to eq(3)

        result = Rbac.search(:class  => "Vm",
                             :user   => user,
                             :filter => MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "2011-01-11"})
                            ).first
        expect(result.length).to eq(17)

        # TODO: More tests with time zone
      end
    end

    context "with group's VMs" do
      before(:each) do
        group2 = FactoryGirl.create(:miq_group, :role => 'support')
        4.times do |i|
          FactoryGirl.create(:vm_vmware,
                             :name             => "Test VM #{i}",
                             :connection_state => i < 2 ? 'connected' : 'disconnected',
                             :miq_group        => i.even? ? group : group2)
        end
      end

      it "when filtering on a real column" do
        filter = YAML.load '--- !ruby/object:MiqExpression
        context_type:
        exp:
          CONTAINS:
            value: connected
            field: MiqGroup.vms-connection_state
        '
        results, attrs = described_class.search(:class => "MiqGroup", :filter => filter, :results_format => :objects)

        expect(results.length).to eq(2)
        expect(attrs[:total_count]).to eq(2)
      end

      it "when filtering on a virtual column (FB15509)" do
        filter = YAML.load '--- !ruby/object:MiqExpression
        context_type:
        exp:
          CONTAINS:
            value: false
            field: MiqGroup.vms-disconnected
        '
        results, attrs = described_class.search(:class => "MiqGroup", :filter => filter, :results_format => :objects)

        expect(results.length).to eq(2)
        expect(attrs[:total_count]).to eq(2)
      end
    end

    context "database configuration" do
      it "expect all database setting values returned" do
        results = Rbac.search(:class               => "VmdbDatabaseSetting",
                              :userid              => "admin",
                              :parent              => nil,
                              :parent_method       => nil,
                              :targets_hash        => true,
                              :association         => nil,
                              :filter              => nil,
                              :sub_filter          => nil,
                              :where_clause        => nil,
                              :named_scope         => nil,
                              :display_filter_hash => nil,
                              :conditions          => nil,
                              :results_format      => :objects,
                              :include_for_find    => {:description => {}, :minimum_value => {}, :maximum_value => {}}
                             ).first

        expect(results.length).to eq(VmdbDatabaseSetting.all.length)
      end
    end
  end

  describe ".filter" do
    let(:vm_location_filter) do
      MiqExpression.new("=" => {"field" => "Vm-location", "value" => "good"})
    end

    let(:matched_vms) { FactoryGirl.create_list(:vm_vmware, 2, :location => "good") }
    let(:other_vms)   { FactoryGirl.create_list(:vm_vmware, 1, :location => "other") }
    let(:all_vms)     { matched_vms + other_vms }
    let(:partial_matched_vms) { [matched_vms.first] }
    let(:partial_vms) { partial_matched_vms + other_vms }

    it "skips rbac on empty empty arrays" do
      all_vms
      expect(Rbac.filtered([], :class => Vm)).to eq([])
    end

    # fix once Rbac filtered is fixed
    skip "skips rbac on nil targets" do
      all_vms
      expect(Rbac.filtered(nil, :class => Vm)).to match_array(all_vms)
    end

    it "supports class target" do
      all_vms
      expect(Rbac.filtered(Vm)).to match_array(all_vms)
    end

    it "supports scope all target" do
      all_vms
      expect(Rbac.filtered(Vm.all)).to match_array(all_vms)
    end

    it "supports scope all target" do
      all_vms
      expect(Rbac.filtered(Vm.where(:location => "good"))).to match_array(matched_vms)
    end

    # it returns objects too
    # TODO: cap number of queries here
    it "runs rbac on array target" do
      all_vms
      expect(Rbac.filtered(all_vms, :class => Vm)).to match_array(all_vms)
    end
  end

  # -------------------------------
  # find targets with rbac are split up into 4 types

  # determine what to run
  it ".apply_rbac_to_class?" do
    expect(Rbac.apply_rbac_to_class?(Vm)).to be_truthy
    expect(Rbac.apply_rbac_to_class?(Rbac)).not_to be
  end

  it ".apply_rbac_to_associated_class?" do
    expect(Rbac.apply_rbac_to_associated_class?(HostMetric)).to be_truthy
    expect(Rbac.apply_rbac_to_associated_class?(Vm)).not_to be
  end

  it ".apply_user_group_rbac_to_class?" do
    expect(Rbac.apply_user_group_rbac_to_class?(User)).to be_truthy
    expect(Rbac.apply_user_group_rbac_to_class?(Vm)).not_to be
  end

  # find_targets_with_direct_rbac(klass, scope, rbac_filters, find_options, user_or_group)
  describe "find_targets_with_direct_rbac" do
    let(:host_filter_find_options) do
      {:conditions => {"hosts.hostname" => "good"}, :include => "host"}
    end

    let(:host_match) { FactoryGirl.create(:host, :hostname => 'good') }
    let(:host_other) { FactoryGirl.create(:host, :hostname => 'bad') }
    let(:vms_match) { FactoryGirl.create_list(:vm_vmware, 2, :host => host_match) }
    let(:vm_host2) { FactoryGirl.create_list(:vm_vmware, 1, :host => host_other) }
    let(:all_vms) { vms_match + vm_host2 }

    it "works with no filters" do
      all_vms
      result = Rbac.find_targets_with_direct_rbac(Vm, Vm, {})
      expect_counts(result, all_vms, all_vms.size, all_vms.size)
    end

    # most of the functionality of search is channeled through find_options. including filters
    # including :conditions, :include, :order, :limit
    it "applies find_options[:conditions, :include]" do
      all_vms
      result = Rbac.find_targets_with_direct_rbac(Vm, Vm, {}, host_filter_find_options)
      expect_counts(result, vms_match, 2, 2)
    end
  end

  private

  # separate them to match easier for failures
  def expect_counts(actual, expected_targets, expected_count, expected_auth_count)
    expect(actual[1]).to eq(expected_count)
    expect(actual[2]).to eq(expected_auth_count)
    expect(actual[0].to_a).to match_array(expected_targets)
  end
end
