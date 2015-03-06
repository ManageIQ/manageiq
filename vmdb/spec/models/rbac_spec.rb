require "spec_helper"

describe Rbac do
  before(:each) do
    User.stub(:server_timezone => "UTC")

    MiqRegion.seed
    @tags = {
      2  => "/managed/environment/prod",
      3  => "/managed/environment/dev",
      4  => "/managed/service_level/gold",
      5  => "/managed/service_level/silver"
    }

    User.any_instance.stub(:validate => true)
    @group = FactoryGirl.create(:miq_group)
    @user  = FactoryGirl.create(:user, :miq_groups => [@group])
  end

  context "with Hosts" do
    before(:each) do
      @host1 = FactoryGirl.create(:host, :name => "Host1", :hostname => "host1.local")
      @host2 = FactoryGirl.create(:host, :name => "Host2", :hostname => "host2.local")
      @hosts = [@host1, @host2]
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
          @group.update_attributes(:filters => {"managed"=>[["/managed/environment/prod"], ["/managed/service_level/silver"]], "belongsto"=>[]})

          @tags = ["/managed/environment/prod"]
          @host2.tag_with(@tags.join(' '), :ns => '*')
          @tags << "/managed/service_level/silver"
        end

        it ".search finds the right HostPerformance rows" do
          @host1.tag_with(@tags.join(' '), :ns => '*')
          results, attrs = Rbac.search(:class => "HostPerformance", :userid => @user.userid, :results_format => :objects)
          attrs[:user_filters].should == @group.filters
          attrs[:total_count].should == @timestamps.length * @hosts.length
          attrs[:auth_count].should  == @timestamps.length
          results.length.should == @timestamps.length
          results.each { |vp| vp.resource.should == @host1 }
        end

        it ".search filters out the wrong HostPerformance rows with :match_via_descendants option" do
          @vm = FactoryGirl.create(:vm_vmware, :name => "VM1", :host => @host2)
          @vm.tag_with(@tags.join(' '), :ns => '*')
          results, attrs = Rbac.search(:targets => HostPerformance.all, :class => "HostPerformance", :userid => @user.userid, :results_format => :objects, :match_via_descendants => { "VmOrTemplate" => :host } )
          attrs[:user_filters].should == @group.filters
          attrs[:total_count].should == @timestamps.length * @hosts.length
          attrs[:auth_count].should  == @timestamps.length
          results.length.should == @timestamps.length
          results.each { |vp| vp.resource.should == @host2 }

          results, attrs = Rbac.search(:targets => HostPerformance.all, :class => "HostPerformance", :userid => @user.userid, :results_format => :objects, :match_via_descendants => "Vm" )
          attrs[:user_filters].should == @group.filters
          attrs[:total_count].should == @timestamps.length * @hosts.length
          attrs[:auth_count].should  == @timestamps.length
          results.length.should == @timestamps.length
          results.each { |vp| vp.resource.should == @host2 }
        end

        it ".search filters out the wrong HostPerformance rows" do
          @host1.tag_with(@tags.join(' '), :ns => '*')
          results, attrs = Rbac.search(:targets => HostPerformance.all, :class => "HostPerformance", :userid => @user.userid, :results_format => :objects)
          attrs[:user_filters].should == @group.filters
          attrs[:total_count].should == @timestamps.length * @hosts.length
          attrs[:auth_count].should  == @timestamps.length
          results.length.should == @timestamps.length
          results.each { |vp| vp.resource.should == @host1 }
        end
      end

      context "with only belongsto filters" do
        before(:each) do
          @group.update_attributes(:filters => { "managed" => [], "belongsto" => ["/belongsto/ExtManagementSystem|ems1"] })

          ems1 = FactoryGirl.create(:ems_vmware, :name => 'ems1')
          @host1.update_attributes(:ext_management_system => ems1)
          @host2.update_attributes(:ext_management_system => ems1)

          root = FactoryGirl.create(:ems_folder, :name => "Datacenters")
          root.parent = ems1
          dc   = FactoryGirl.create(:ems_folder, :name => "Datacenter1")
          dc.parent = root
          hfolder   = FactoryGirl.create(:ems_folder, :name => "Hosts")
          hfolder.parent = dc
          @host1.parent = hfolder
        end

        it ".search finds the right HostPerformance rows" do
          results, attrs = Rbac.search(:class => "HostPerformance", :userid => @user.userid, :results_format => :objects)
          attrs[:user_filters].should == @group.filters
          attrs[:total_count].should == @timestamps.length * @hosts.length
          attrs[:auth_count].should  == @timestamps.length
          results.length.should == @timestamps.length
          results.each { |vp| vp.resource.should == @host1 }
        end

        it ".search filters out the wrong HostPerformance rows" do
          results, attrs = Rbac.search(:targets => HostPerformance.all, :class => "HostPerformance", :userid => @user.userid, :results_format => :objects)
          attrs[:user_filters].should == @group.filters
          attrs[:total_count].should == @timestamps.length * @hosts.length
          attrs[:auth_count].should  == @timestamps.length
          results.length.should == @timestamps.length
          results.each { |vp| vp.resource.should == @host1 }
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
        results = Rbac.search(:class => "TemplateVmware", :conditions => ["ems_id IS NULL"], :results_format => :objects)
        objects = results.first
        objects.should == []

        @template.update_attributes(:ext_management_system => nil)
        results = Rbac.search(:class => "TemplateVmware", :conditions => ["ems_id IS NULL"], :results_format => :objects)
        objects = results.first
        objects.should == [@template]
      end

      context "search on EMSes" do
        before(:each) do
         @ems2 = FactoryGirl.create(:ems_vmware, :name => 'ems2')
        end

        it "preserves order of targets" do
          @ems3 = FactoryGirl.create(:ems_vmware, :name => 'ems3')
          @ems4 = FactoryGirl.create(:ems_vmware, :name => 'ems4')

          targets = [@ems2, @ems4, @ems3, @ems]

          results = Rbac.search(:targets => targets, :results_format => :objects, :userid => @user.userid)
          objects = results.first
          objects.length.should == 4
          objects.should == targets
        end

        it "finds both EMSes without belongsto filters" do
          results = Rbac.search(:class => "ExtManagementSystem", :results_format => :objects, :userid => @user.userid)
          objects = results.first
          objects.length.should == 2
        end

        it "finds one EMS with belongsto filters" do
          @group.update_attributes(:filters => { "managed" => [], "belongsto" => [@vm_folder_path] })
          results = Rbac.search(:class => "ExtManagementSystem", :results_format => :objects, :userid => @user.userid)
          objects = results.first
          objects.should == [@ems]
        end
      end

      it "search on VMs and Templates should return no objects if self-service user" do
        User.any_instance.stub(:self_service? => true)
        User.with_userid(@user.userid) do
          results = Rbac.search(:class => "VmOrTemplate", :results_format => :objects)
          objects = results.first
          objects.length.should == 0
        end
      end

      it "search on VMs and Templates should return both objects" do
        results = Rbac.search(:class => "VmOrTemplate", :results_format => :objects)
        objects = results.first
        objects.length.should == 2
        objects.should match_array([@vm, @template])

        @group.update_attributes(:filters => { "managed" => [], "belongsto" => [@vm_folder_path] })
        results = Rbac.search(:class => "VmOrTemplate", :results_format => :objects, :userid => @user.userid)
        objects = results.first
        objects.length.should == 0

        [@vm, @template].each do |v|
          v.with_relationship_type("ems_metadata") { v.parent = @vfolder }
          v.save
        end

        @group.update_attributes(:filters => { "managed" => [], "belongsto" => [@vm_folder_path] })
        results = Rbac.search(:class => "VmOrTemplate", :results_format => :objects, :userid => @user.userid)
        objects = results.first
        objects.length.should == 2
        objects.should match_array([@vm, @template])
      end

      it "search on VMs should return a single object" do
        results = Rbac.search(:class => "Vm", :results_format => :objects)
        objects = results.first
        objects.length.should == 1
        objects.should match_array([@vm])

        @group.update_attributes(:filters => { "managed" => [], "belongsto" => [@vm_folder_path] })

        results = Rbac.search(:class => "Vm", :results_format => :objects, :userid => @user.userid)
        objects = results.first
        objects.length.should == 0

        [@vm, @template].each do |v|
          v.with_relationship_type("ems_metadata") { v.parent = @vfolder }
          v.save
        end

        @group.update_attributes(:filters => { "managed" => [], "belongsto" => [@vm_folder_path] })
        results = Rbac.search(:class => "Vm", :results_format => :objects, :userid => @user.userid)
        objects = results.first
        objects.length.should == 1
        objects.should match_array([@vm])
      end

      it "search on Templates should return a single object" do
        results = Rbac.search(:class => "MiqTemplate", :results_format => :objects)
        objects = results.first
        objects.length.should == 1
        objects.should match_array([@template])

        @group.update_attributes(:filters => { "managed" => [], "belongsto" => [@vm_folder_path] })

        results = Rbac.search(:class => "MiqTemplate", :results_format => :objects, :userid => @user.userid)
        objects = results.first
        objects.length.should == 0

        [@vm, @template].each do |v|
          v.with_relationship_type("ems_metadata") { v.parent = @vfolder }
          v.save
        end

        @group.update_attributes(:filters => { "managed" => [], "belongsto" => [@vm_folder_path] })
        results = Rbac.search(:class => "MiqTemplate", :results_format => :objects, :userid => @user.userid)
        objects = results.first
        objects.length.should == 1
        objects.should match_array([@template])
      end
    end

    context "when applying a filter to the host's cluster (FB17114)" do
      before(:each) do
        @ems = FactoryGirl.create(:ems_vmware, :name => 'ems')
        @ems_folder_path = "/belongsto/ExtManagementSystem|#{@ems.name}"
        @root   = FactoryGirl.create(:ems_folder, :name => "Datacenters")
        @root.parent = @ems
        @mtc   = FactoryGirl.create(:ems_folder, :name => "MTC", :is_datacenter => true)
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

      it "get all the descendants without belongsto filter" do
        results, attrs = Rbac.search(:class => "Host", :userid => @user.userid, :results_format => :objects)
        results.length.should == 4
        attrs[:total_count].should == 4
        attrs[:auth_count].should == 4
        attrs[:user_filters].should == {"managed"=>[], "belongsto"=>[]}

        results2, attrs = Rbac.search(:class => "Vm", :userid => @user.userid, :results_format => :objects)
        results2.length.should == 2

        results3, attrs = Rbac.search(:class => "VmOrTemplate", :userid => @user.userid, :results_format => :objects)
        results3.length.should == 4
      end

      it "get all the vm or templates with belongsto filter" do
        @group.update_attributes(:filters => { "managed" => [], "belongsto" => [@cluster_folder_path] })
        results, attrs = Rbac.search(:class => "VmOrTemplate", :userid => @user.userid, :results_format => :objects)
        results.length.should == 0
        attrs[:total_count].should == 4
        attrs[:auth_count].should == 0

        [@vm1, @template1].each do |v|
          v.with_relationship_type("ems_metadata") { v.parent = @rp }
          v.save
        end
        @group.update_attributes(:filters => { "managed" => [], "belongsto" => [@cluster_folder_path] })

        results2, attrs = Rbac.search(:class => "VmOrTemplate", :userid => @user.userid, :results_format => :objects)
        attrs[:user_filters].should == {"managed"=>[], "belongsto"=>[@cluster_folder_path]}
        attrs[:total_count].should == 4
        attrs[:auth_count].should == 2
        results2.length.should == 2
      end

      it "get all the hosts with belongsto filter" do
        @group.update_attributes(:filters => { "managed" => [], "belongsto" => [@cluster_folder_path] })
        results, attrs = Rbac.search(:class => "Host", :userid => @user.userid, :results_format => :objects)
        attrs[:user_filters].should == {"managed"=>[], "belongsto"=>[@cluster_folder_path]}
        attrs[:total_count].should == 4
        attrs[:auth_count].should == 1
        results.length.should == 1

        @group.update_attributes(:filters => { "managed" => [], "belongsto" => [@mtc_folder_path] })
        results2, attrs = Rbac.search(:class => "Host", :userid => @user.userid, :results_format => :objects)
        attrs[:user_filters].should == {"managed"=>[], "belongsto"=>[@mtc_folder_path]}
        attrs[:total_count].should == 4
        attrs[:auth_count].should == 1
        results2.length.should == 1

        @group.update_attributes(:filters => { "managed" => [], "belongsto" => [@ems_folder_path] })
        results3, attrs = Rbac.search(:class => "Host", :userid => @user.userid, :results_format => :objects)
        attrs[:user_filters].should == {"managed"=>[], "belongsto"=>[@ems_folder_path]}
        attrs[:total_count].should == 4
        attrs[:auth_count].should == 1
        results3.length.should == 1
      end
    end
  end

  context "with services" do
    before(:each) do
      @service1 = FactoryGirl.create(:service)
      @service2 = FactoryGirl.create(:service)
      @service3 = FactoryGirl.create(:service, :evm_owner => @user)
      @service4 = FactoryGirl.create(:service, :miq_group => @group)
      @service5 = FactoryGirl.create(:service, :evm_owner => @user, :miq_group => @group)
    end

    context ".search" do

      it "self-service group" do
        MiqGroup.any_instance.stub(:self_service? => true)

        results, attrs = Rbac.search(:class => "Service", :results_format => :objects, :miq_group_id => @user.current_group.id)
        results.to_a.should match_array([@service4, @service5])
      end

      context "with self-service user" do
        before(:each) do
          User.any_instance.stub(:self_service? => true)
        end

        it "works when targets are empty" do
          User.with_userid(@user.userid) do
            results, attrs = Rbac.search(:class => "Service", :results_format => :objects)
            results.to_a.should match_array([@service3, @service4, @service5])
          end
        end
      end

      it "limited self-service group" do
        MiqGroup.any_instance.stub(:self_service? => true)
        MiqGroup.any_instance.stub(:limited_self_service? => true)

        results, attrs = Rbac.search(:class => "Service", :results_format => :objects, :miq_group_id => @user.current_group.id)
        results.to_a.should match_array([@service4, @service5])
      end

      context "with limited self-service user" do
        before(:each) do
          User.any_instance.stub(:self_service? => true)
          User.any_instance.stub(:limited_self_service? => true)
        end

        it "works when targets are empty" do
          User.with_userid(@user.userid) do
            results, attrs = Rbac.search(:class => "Service", :results_format => :objects)
            results.to_a.should match_array([@service3, @service5])
          end
        end
      end


      it "works when targets are a list of ids" do
        results, attrs = Rbac.search(:targets => Service.all.collect(&:id), :class => "Service", :results_format => :objects)
        results.length.should == 5
        results.first.should be_kind_of(Service)

        results, attrs = Rbac.search(:targets => Service.all.collect(&:id), :class => "Service", :results_format => :ids)
        results.length.should == 5
        results.first.should be_kind_of(Integer)
      end

      it "works when targets are empty" do
        results, attrs = Rbac.search(:class => "Service", :results_format => :objects)
        results.length.should == 5
      end
    end
  end

  context "with tagged VMs" do
    before(:each) do
      @hosts = [
        FactoryGirl.create(:host, :name => "Host1", :hostname => "host1.local"),
        FactoryGirl.create(:host, :name => "Host2", :hostname => "host2.local"),
        FactoryGirl.create(:host, :name => "Host3", :hostname => "host3.local"),
        FactoryGirl.create(:host, :name => "Host4", :hostname => "host4.local")
      ]

      4.times do |i|
        group = i + 1
        guest_os = %w{_none_ windows ubuntu windows ubuntu}[group]
        vm = FactoryGirl.build(:vm_vmware, :name => "Test Group #{group} VM #{i}")
        vm.hardware = FactoryGirl.build(:hardware, :numvcpus => (group * 2), :memory_cpu => (group * 1.megabytes), :guest_os => guest_os)
        vm.host = @hosts[group-1]
        vm.evm_owner_id = @user.id  if (i.even?)
        vm.miq_group_id = @group.id if (i.odd?)
        vm.save
        tags = []
        @tags.each { |n,t| tags << t if (i > 0) }
        vm.tag_with(tags.join(" "), :ns => "*") unless tags.empty?
      end

      Vm.scope :group_scope,   lambda { |group_num| {:conditions => ["name LIKE ?", "Test Group #{group_num}%"]} }
    end

    context ".search" do

      it "self-service group" do
        MiqGroup.any_instance.stub(:self_service? => true)

        results, attrs = Rbac.search(:class => "Vm", :results_format => :objects, :miq_group_id => @user.current_group.id)
        results.length.should == 2
      end

      context "with self-service user" do
        before(:each) do
          User.any_instance.stub(:self_service? => true)
        end

        it "works when targets are empty" do
          User.with_userid(@user.userid) do
            results, attrs = Rbac.search(:class => "Vm", :results_format => :objects)
            results.length.should == 4
          end
        end

        it "works when passing a named_scope" do
          User.with_userid(@user.userid) do
            results, attrs = Rbac.search(:class => "Vm", :results_format => :objects, :named_scope => [:group_scope, 1])
            results.length.should == 1
          end
        end
      end

      it "limited self-service group" do
        MiqGroup.any_instance.stub(:self_service? => true)
        MiqGroup.any_instance.stub(:limited_self_service? => true)

        results, attrs = Rbac.search(:class => "Vm", :results_format => :objects, :miq_group_id => @user.current_group.id)
        results.length.should == 2
      end

      context "with limited self-service user" do
        before(:each) do
          User.any_instance.stub(:self_service? => true)
          User.any_instance.stub(:limited_self_service? => true)
        end

        it "works when targets are empty" do
          User.with_userid(@user.userid) do
            results, attrs = Rbac.search(:class => "Vm", :results_format => :objects)
            results.length.should == 2
          end
        end

        it "works when passing a named_scope" do
          User.with_userid(@user.userid) do
            results, attrs = Rbac.search(:class => "Vm", :results_format => :objects, :named_scope => [:group_scope, 1])
            results.length.should == 1

            results, attrs = Rbac.search(:class => "Vm", :results_format => :objects, :named_scope => [:group_scope, 2])
            results.length.should == 0
          end
        end
      end

      it "works when targets are a list of ids" do
        results, attrs = Rbac.search(:targets => Vm.all.collect(&:id), :class => "Vm", :results_format => :objects)
        results.length.should == 4
        results.first.should be_kind_of(Vm)

        results, attrs = Rbac.search(:targets => Vm.all.collect(&:id), :class => "Vm", :results_format => :ids)
        results.length.should == 4
        results.first.should be_kind_of(Integer)
      end

      it "works when targets are empty" do
        results, attrs = Rbac.search(:class => "Vm", :results_format => :objects)
        results.length.should == 4
      end

      it "works when passing a named_scope" do
        results, attrs = Rbac.search(:class => "Vm", :results_format => :objects, :named_scope => [:group_scope, 4])
        results.length.should == 1
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
        results, attrs = Rbac.search(:class => "Vm", :filter => YAML.load(filter), :results_format => :objects)
        results.length.should == 2
      end
    end

    context "with only managed filters (FB9153, FB11442)" do
      before(:each) do
        @group.update_attributes(:filters => {"managed"=>[["/managed/environment/prod"], ["/managed/service_level/silver"]], "belongsto"=>[]})
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
          results = nil
          lambda { results, attrs = Rbac.search(:class => "Vm", :filter => exp, :userid => @user.userid, :results_format => :objects, :order => "vms.name desc") }.should_not raise_error
          # results.each {|r| $log.info("XXX: result: #{r.name}")}
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
          results, attrs = Rbac.search(:class => "Vm", :filter => exp, :userid => @user.userid, :results_format => :objects, :limit => 2, :offset => 2, :order => "vms.name desc")
          results.length.should == 1
          results.first.name.should == "Test Group 2 VM 1"
          attrs[:auth_count].should == 3
          attrs[:total_count].should == 4
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

          results, attrs = Rbac.search(:class => "EmsEvent", :filter => exp, :userid => @user.userid, :results_format => :objects)

          EmsEvent.all.each {|r| $log.info("XXX: event: [#{r.id}], #{r.timestamp}")}
          results.each {|r| $log.info("XXX: result: #{r.message}")}
          results.length.should == 2
          attrs[:auth_count].should == 2
          attrs[:user_filters]["managed"].should == @group.filters['managed']
          attrs[:total_count].should == 2
        end
      end
    end
  end

  context "Evaluating date/time expressions" do
    before(:each) do
      Timecop.freeze("2011-01-11 17:30 UTC")

      @user.settings = {:display => {:timezone => "Eastern Time (US & Canada)"}}
      @user.save
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
      result, attrs = Rbac.search(:class => "Vm", :filter => MiqExpression.new({"AFTER" => {"field" => "Vm-last_scan_on", "value" => "2011-01-11 9:00"}}))
      result.length.should == 13

      result, attrs = Rbac.search(:class => "Vm", :filter => MiqExpression.new({">" => {"field" => "Vm-last_scan_on", "value" => "2011-01-11 9:00"}}))
      result.length.should == 13

      # Test IS EMPTY and IS NOT EMPTY
      result, attrs = Rbac.search(:class => "Vm", :filter => MiqExpression.new({"IS EMPTY"=>{"field"=>"Vm-last_scan_on"}}))
      result.length.should == 2

      result, attrs = Rbac.search(:class => "Vm", :filter => MiqExpression.new({"IS EMPTY"=>{"field"=>"Vm-retires_on"}}))
      result.length.should == 2

      result, attrs = Rbac.search(:class => "Vm", :filter => MiqExpression.new({"IS NOT EMPTY"=>{"field"=>"Vm-last_scan_on"}}))
      result.length.should == 60

      result, attrs = Rbac.search(:class => "Vm", :filter => MiqExpression.new({"IS NOT EMPTY"=>{"field"=>"Vm-retires_on"}}))
      result.length.should == 60

      # Test IS
      result, attrs = Rbac.search(:class => "Vm", :filter => MiqExpression.new({"IS" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}}))
      result.length.should == 3

      result, attrs = Rbac.search(:class => "Vm", :filter => MiqExpression.new({"IS" => {"field" => "Vm-last_scan_on", "value" => "2011-01-11"}}))
      result.length.should == 22

      result, attrs = Rbac.search(:class => "Vm", :filter => MiqExpression.new({"IS" => {"field" => "Vm-last_scan_on", "value" => "Today"}}))
      result.length.should == 22

      result, attrs = Rbac.search(:class => "Vm", :filter => MiqExpression.new({"IS" => {"field" => "Vm-last_scan_on", "value" => "3 Hours Ago"}}))
      result.length.should == 1

      result, attrs = Rbac.search(:class => "Vm", :filter => MiqExpression.new({"IS" => {"field" => "Vm-retires_on", "value" => "3 Hours Ago"}}))
      result.length.should == 22

      result, attrs = Rbac.search(:class => "Vm", :filter => MiqExpression.new({"IS" => {"field" => "Vm-last_scan_on", "value" => "Last Month"}}))
      result.length.should == 9

      # Test FROM
      result, attrs = Rbac.search(:class => "Vm",
        :filter => MiqExpression.new(
          {"FROM" => {"field" => "Vm-last_scan_on", "value" => ["2010-07-11", "2010-12-31"]}}
        )
      )
      result.length.should == 20

      result, attrs = Rbac.search(:class => "Vm",
        :filter => MiqExpression.new(
          {"FROM" => {"field" => "Vm-retires_on", "value" => ["2010-07-11", "2010-12-31"]}}
        )
      )
      result.length.should == 20

      result, attrs = Rbac.search(:class => "Vm",
        :filter => MiqExpression.new(
          {"FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-09 17:00", "2011-01-10 23:30:59"]}}
        )
      )
      result.length.should == 4

      result, attrs = Rbac.search(:class => "Vm", :filter => MiqExpression.new({"FROM" => {"field" => "Vm-retires_on", "value" => ["Last Week", "Last Week"]}}))
      result.length.should == 8

      result, attrs = Rbac.search(:class => "Vm", :filter => MiqExpression.new({"FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Week", "Last Week"]}}))
      result.length.should == 8

      result, attrs = Rbac.search(:class => "Vm", :filter => MiqExpression.new({"FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Week", "This Week"]}}))
      result.length.should == 33

      result, attrs = Rbac.search(:class => "Vm", :filter => MiqExpression.new({"FROM" => {"field" => "Vm-last_scan_on", "value" => ["2 Months Ago", "1 Month Ago"]}}))
      result.length.should == 14

      result, attrs = Rbac.search(:class => "Vm", :filter => MiqExpression.new({"FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Month", "Last Month"]}}))
      result.length.should == 9

      # Inside a find/check expression
      result, attrs = Rbac.search(:class => "Host", :filter => MiqExpression.new(
        {"FIND"=>{
          "checkany"=>{"FROM" => {"field" => "Host.vms-last_scan_on", "value" => ["2011-01-08 17:00", "2011-01-09 23:30:59"]}},
          "search"=>{"IS NOT NULL"=>{"field"=>"Host.vms-name"}}}
        }
      ))
      result.length.should == 1

      result, attrs = Rbac.search(:class => "Host", :filter => MiqExpression.new(
        {"FIND"=>{
          "search"=>{"FROM" => {"field" => "Host.vms-last_scan_on", "value" => ["2011-01-08 17:00", "2011-01-09 23:30:59"]}},
          "checkall"=>{"IS NOT NULL"=>{"field"=>"Host.vms-name"}}}
        }
      ))
      result.length.should == 1

      # Test FROM with time zone
      result, attrs = Rbac.search(:class => "Vm",
        :userid => @user.userid,
        :filter => MiqExpression.new(
          {"FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-09 17:00", "2011-01-10 23:30:59"]}}
        )
      )
      result.length.should == 8

      # Test IS with time zone
      result, attrs = Rbac.search(:class => "Vm",
        :userid => @user.userid,
        :filter => MiqExpression.new({"IS" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
      )
      result.length.should == 3

      result, attrs = Rbac.search(:class => "Vm",
        :userid => @user.userid,
        :filter => MiqExpression.new({"IS" => {"field" => "Vm-last_scan_on", "value" => "2011-01-11"}})
      )
      result.length.should == 17

      # TODO: More tests with time zone
    end
  end

  context "with group's VMs" do
    before(:each) do
      role2 = FactoryGirl.create(:miq_user_role, :name => 'support')
      group2 = FactoryGirl.create(:miq_group, :description => "Support Group", :miq_user_role => role2)
      4.times do |i|
        case i
        when 0
          group_id = @group.id
          state = 'connected'
        when 1
          group_id = group2.id
          state = 'connected'
        when 2
          group_id = @group.id
          state = 'disconnected'
        when 3
          group_id = group2.id
          state = 'disconnected'
        end
        vm = FactoryGirl.create(:vm_vmware, :name => "Test VM #{i}", :connection_state => state, :miq_group_id => group_id)
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

      results.length.should == 2
      attrs[:total_count].should == 2
    end

    it "when filtering on a virtual column (FB15509)" do
      filter = YAML.load '--- !ruby/object:MiqExpression
      context_type:
      exp:
        CONTAINS:
          value: false
          field: MiqGroup.vms-disconnected
      '
      results, attrs = described_class.search(:class => "MiqGroup", :userid => "admin", :filter => filter, :results_format => :objects)

      results.length.should == 2
      attrs[:total_count].should == 2
    end
  end
end
