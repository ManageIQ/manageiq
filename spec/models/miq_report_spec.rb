require "spec_helper"

describe MiqReport do
  it "attr_accessors are serializable via yaml" do
    result = [{"id" => 5, "vmm_vendor" => "VMware", "vmm_product" => "ESXi", "ipaddress" => "192.168.252.13", "vmm_buildnumber" => "260247", "vmm_version" => "4.1.0", "name" => "VI4ESXM1.manageiq.com"}, {"id" => 3, "vmm_vendor" => "VMware", "vmm_product" => "ESXi", "ipaddress" => "192.168.252.9", "vmm_buildnumber" => "348481", "vmm_version" => "4.1.0", "name" => "vi4esxm2.manageiq.com"}, {"id" => 4, "vmm_vendor" => "VMware", "vmm_product" => "ESX", "ipaddress" => "192.168.252.10", "vmm_buildnumber" => "502767", "vmm_version" => "4.1.0", "name" => "vi4esxm3.manageiq.com"}, {"id" => 1, "vmm_vendor" => "VMware", "vmm_product" => "ESXi", "ipaddress" => "192.168.252.4", "vmm_buildnumber" => "504850", "vmm_version" => "4.0.0", "name" => "per410a-t5.manageiq.com"}]
    column_names = ["name", "ipaddress", "vmm_vendor", "vmm_product", "vmm_version", "vmm_buildnumber", "id"]
    fake_ruport_data_table = {:data => result, :column_names => column_names}
    before = MiqReport.new
    before.table = fake_ruport_data_table
    after = YAML.load(YAML.dump(before))
    after.table.should == fake_ruport_data_table
  end

  it '.get_expressions_by_model' do
    FactoryGirl.create(:miq_report, :conditions => nil)
    rep_nil = FactoryGirl.create(:miq_report)

    # FIXME: find a way to do this in a factory
    serialized_nil = "--- !!null \n...\n"
    ActiveRecord::Base.connection.execute("update miq_reports set conditions='#{serialized_nil}' where id=#{rep_nil.id}")

    rep_ok  = FactoryGirl.create(:miq_report, :conditions => "SOMETHING")
    reports = MiqReport.get_expressions_by_model('Vm')
    expect(reports).to eq(rep_ok.name => rep_ok.id)
  end

  it "paged_view_search on vmdb_* tables" do
    # Create EVM tables/indexes and hourly metric data...
    table = FactoryGirl.create(:vmdb_table_evm, :name => "accounts")
    index = FactoryGirl.create(:vmdb_index, :name => "accounts_pkey", :vmdb_table => table)
    FactoryGirl.create(:vmdb_metric, :resource => index, :timestamp => Time.now.utc, :capture_interval_name => 'hourly', :size => 102, :rows => 102, :pages => 102, :wasted_bytes => 102, :percent_bloat => 102)

    report_args = {
      "db"          => "VmdbIndex",
      "cols"        => ["name"],
      "include"     => {"vmdb_table" => {"columns" => ["type"]}, "latest_hourly_metric" => {"columns" => ["rows", "size", "wasted_bytes", "percent_bloat"]}},
      "col_order"   => ["name", "latest_hourly_metric.rows", "latest_hourly_metric.size", "latest_hourly_metric.wasted_bytes", "latest_hourly_metric.percent_bloat"],
      "col_formats" => [nil, nil, :bytes_human, :bytes_human, nil],
    }

    report = MiqReport.new(report_args)

    search_expression = MiqExpression.new("and" => [{"=" => {"value" => "VmdbTableEvm", "field" => "VmdbIndex.vmdb_table-type"}}])

    results, = report.paged_view_search(:filter => search_expression)
    expect(results.data.collect(&:data)).to eq(
      [{
        "name"                               => "accounts_pkey",
        "vmdb_table.type"                    => "VmdbTableEvm",
        "latest_hourly_metric.rows"          => 102,
        "latest_hourly_metric.size"          => 102,
        "latest_hourly_metric.wasted_bytes"  => 102.0,
        "latest_hourly_metric.percent_bloat" => 102.0,
        "id"                                 => index.id
      }]
    )
  end

  context "#paged_view_search" do
    OS_LIST = %w(_none_ windows ubuntu windows ubuntu)

    before(:each) do
      # TODO: Move this setup to the examples that need it.
      @tags = {
        2 => "/managed/environment/prod",
        3 => "/managed/environment/dev",
        4 => "/managed/service_level/gold",
        5 => "/managed/service_level/silver"
      }

      @group = FactoryGirl.create(:miq_group)
      @user  = FactoryGirl.create(:user, :miq_groups => [@group])
    end

    it "filters vms in folders" do
      host = FactoryGirl.create(:host)
      vm1  = FactoryGirl.create(:vm_vmware, :host => host)
      vm2  = FactoryGirl.create(:vm_vmware, :host => host)

      root        = FactoryGirl.create(:ems_folder, :name => "datacenters")
      root.parent = host

      usa         = FactoryGirl.create(:ems_folder, :name => "usa")
      usa.parent  = root

      nyc         = FactoryGirl.create(:ems_folder, :name => "nyc")
      nyc.parent  = usa

      vm1.with_relationship_type("ems_metadata") { vm1.parent = usa }
      vm2.with_relationship_type("ems_metadata") { vm2.parent = nyc }

      report = MiqReport.new(:db => "Vm")

      results, = report.paged_view_search(:parent => usa)
      expect(results.data.collect { |rec| rec.data['id'] }).to eq [vm1.id]

      results, = report.paged_view_search(:parent => root)
      expect(results.data.collect { |rec| rec.data['id'] }).to eq []

      results, = report.paged_view_search(:parent => root, :association => :all_vms)
      expect(results.data.collect { |rec| rec.data['id'] }).to match_array [vm1.id, vm2.id]
    end

    it "paging with order" do
      vm1 = FactoryGirl.create(:vm_vmware)
      vm2 = FactoryGirl.create(:vm_vmware)
      ids = [vm1.id, vm2.id].sort

      report    = MiqReport.new(:db => "Vm", :sortby => "id", :order => "Descending")
      results,  = report.paged_view_search(:page => 2, :per_page => 1)
      found_ids = results.data.collect { |rec| rec.data['id'] }

      expect(found_ids).to eq [ids.first]
    end

    it "target_ids_for_paging caches results" do
      vm = FactoryGirl.create(:vm_vmware)
      FactoryGirl.create(:vm_vmware)

      report        = MiqReport.new(:db => "Vm")
      report.extras = {:target_ids_for_paging => [vm.id], :attrs_for_paging => {}}
      results,      = report.paged_view_search(:page => 1, :per_page => 10)
      found_ids     = results.data.collect { |rec| rec.data['id'] }
      expect(found_ids).to eq [vm.id]
    end

    it "VMs under Host with order" do
      host1 = FactoryGirl.create(:host)
      FactoryGirl.create(:vm_vmware, :host => host1, :name => "a")

      host2 = FactoryGirl.create(:host)
      vmb   = FactoryGirl.create(:vm_vmware, :host => host2, :name => "b")
      vmc   = FactoryGirl.create(:vm_vmware, :host => host2, :name => "c")

      report = MiqReport.new(:db => "Vm", :sortby => "name", :order => "Descending")
      results, = report.paged_view_search(
        :parent      => host2,
        :association => "vms",
        :only        => ["name"],
        :page        => 1,
        :per_page    => 2
      )
      names = results.data.collect(&:name)
      expect(names).to eq [vmc.name, vmb.name]
    end

    it "user managed filters" do
      # TODO: Move user setup code here, remove @user/@group ivars
      vm1 = FactoryGirl.create(:vm_vmware)
      vm1.tag_with("/managed/environment/prod", :ns => "*")

      vm2 = FactoryGirl.create(:vm_vmware)
      vm2.tag_with("/managed/environment/dev", :ns => "*")

      User.stub(:server_timezone => "UTC")
      @group.update_attributes(:filters => {"managed" => [["/managed/environment/prod"]], "belongsto" => []})

      report = MiqReport.new(:db => "Vm")
      results, attrs = report.paged_view_search(
        :only   => ["name"],
        :userid => @user.userid,
      )
      expect(results.length).to eq 1
      expect(results.data.collect(&:name)).to eq [vm1.name]
      expect(report.table.length).to eq 1
      expect(attrs[:apply_sortby_in_search]).to be_true
      expect(attrs[:apply_limit_in_sql]).to be_true
      expect(attrs[:auth_count]).to eq 1
      expect(attrs[:user_filters]["managed"]).to eq [["/managed/environment/prod"]]
      expect(attrs[:total_count]).to eq 2
    end

    it "sortby, order, user filters, where sort column is in a sub-table" do
      vm1 = FactoryGirl.create(:vm_vmware, :name => "VA", :storage => FactoryGirl.create(:storage, :name => "SA"))
      vm2 = FactoryGirl.create(:vm_vmware, :name => "VB", :storage => FactoryGirl.create(:storage, :name => "SB"))
      tag = "/managed/environment/prod"
      @group.update_attributes(:filters => {"managed" => [[tag]], "belongsto" => []})
      vm1.tag_with(tag, :ns => "*")
      vm2.tag_with(tag, :ns => "*")

      User.stub(:server_timezone => "UTC")
      report = MiqReport.new(:db => "Vm", :sortby => ["storage.name", "name"], :order => "Ascending", :include => {"storage" => {"columns" => ["name"]}})
      options = {
        :only   => ["name", "storage.name"],
        :userid => @user.userid,
      }

      results, attrs = report.paged_view_search(options)

      # Why do we need to check all of these things?
      expect(results.length).to eq 2
      expect(results.data.first["name"]).to eq "VA"
      expect(results.data.first["storage.name"]).to eq "SA"
      expect(report.table.length).to eq 2
      expect(attrs[:apply_sortby_in_search]).to be_true
      expect(attrs[:apply_limit_in_sql]).to be_true
      expect(attrs[:auth_count]).to eq 2
      expect(attrs[:user_filters]["managed"]).to eq [[tag]]
      expect(attrs[:total_count]).to eq 2
    end

    it "sorting on a virtual column" do
      FactoryGirl.create(:vm_vmware, :name => "B", :host => FactoryGirl.create(:host, :name => "A"))
      FactoryGirl.create(:vm_vmware, :name => "A", :host => FactoryGirl.create(:host, :name => "B"))

      report = MiqReport.new(:db => "Vm", :sortby => ["host_name", "name"], :order => "Descending")
      options = {
        :only     => ["name", "host_name"],
        :page     => 2,
      }

      results, attrs = report.paged_view_search(options)
      expect(results.length).to eq 2
      expect(results.data.first["host_name"]).to eq "B"
    end

    context "with tagged VMs" do
      before(:each) do
        @hosts = [
          FactoryGirl.create(:host, :name => "Host1", :hostname => "host1.local"),
          FactoryGirl.create(:host, :name => "Host2", :hostname => "host2.local"),
          FactoryGirl.create(:host, :name => "Host3", :hostname => "host3.local"),
          FactoryGirl.create(:host, :name => "Host4", :hostname => "host4.local")
        ]

        100.times do |i|
          case i
          when  0..24 then group = 1
          when 25..49 then group = 2
          when 50..74 then group = 3
          when 75..99 then group = 4
          end
          vm = FactoryGirl.build(:vm_vmware, :name => "Test Group #{group} VM #{i}")
          vm.hardware = FactoryGirl.build(:hardware, :cpu_sockets => (group * 2), :memory_mb => (group * 1.megabytes), :guest_os => OS_LIST[group])
          vm.host = @hosts[group - 1]
          vm.evm_owner_id = @user.id  if ((i % 5) == 0)
          vm.miq_group_id = @group.id if ((i % 7) == 0)
          vm.save
          tags = []
          @tags.each { |n, t| tags << t if (i % n) == 0 }
          vm.tag_with(tags.join(" "), :ns => "*") unless tags.empty?
        end
      end

      context "group has managed filters" do
        before(:each) do
          User.stub(:server_timezone => "UTC")
          @group.update_attributes(:filters => {"managed" => [["/managed/environment/prod"], ["/managed/service_level/silver"]], "belongsto" => []})
        end

        it "works when sorting on a column in a sub-table" do
          report = MiqReport.new(:db => "Vm", :cols => ["name", "host.name"], :include => {"host" => {"columns" => ["name"]}}, :sortby => ["host.name", "name"], :order => "Descending")
          options = {
            :only     => ["name", "host.name"],
            :page     => 2,
            :per_page => 10
          }
          results, attrs = report.paged_view_search(options)
          results.length.should == 10
          results.data.first["name"].should == "Test Group 1 VM 21"
          results.data.last["name"].should == "Test Group 1 VM 13"
          attrs[:apply_sortby_in_search].should be_true
          attrs[:apply_limit_in_sql].should be_true
          attrs[:auth_count].should == 100
          attrs[:user_filters]["managed"].should be_empty
          attrs[:total_count].should == 100

          report = MiqReport.new(:db => "Vm", :include_for_find => {:hardware => {}}, :include => {"hardware" => {"columns" => ["guest_os"]}}, :sortby => ["hardware.guest_os", "name"], :order => "Descending")
          options = {
            :only     => ["name", "hardware.guest_os"],
            :page     => 2,
            :per_page => 10
          }
          results, attrs = report.paged_view_search(options)
          results.length.should == 10
          results.data.first["name"].should == "Test Group 4 VM 89"
          results.data.last["name"].should == "Test Group 4 VM 80"
          attrs[:apply_sortby_in_search].should be_true
          attrs[:apply_limit_in_sql].should be_true
          attrs[:auth_count].should == 100
          attrs[:user_filters]["managed"].should be_empty
          attrs[:total_count].should == 100
        end

        it "works when filtering on a virtual column" do
          report = MiqReport.new(:db => "Vm", :sortby => ["name"], :order => "Ascending")
          filter = YAML.load '--- !ruby/object:MiqExpression
          exp:
            and:
            - IS NOT NULL:
                field: Vm-name
                value: ""
            - IS NOT EMPTY:
                field: Vm-created_on
                value: ""
            - and:
              - IS NOT NULL:
                  field: Vm-host_name
                  value: ""
          '

          options = {
            :only     => ["name", "host_name"],
            :page     => 2,
            :per_page => 10,
            :filter   => filter
          }
          results, attrs = report.paged_view_search(options)
          results.length.should == 10
          results.data.first["name"].should == "Test Group 1 VM 18"
          results.data.last["name"].should == "Test Group 1 VM 4"
          attrs[:apply_sortby_in_search].should be_true
          attrs[:apply_limit_in_sql].should be_false
          attrs[:auth_count].should == 100
          attrs[:user_filters]["managed"].should be_empty
          attrs[:total_count].should == 100
        end

        it "works when filtering on a virtual column and user filters are passed" do
          report = MiqReport.new(:db => "Vm", :sortby => ["name"], :order => "Descending")
          filter = YAML.load '--- !ruby/object:MiqExpression
          exp:
            and:
            - IS NOT NULL:
                field: Vm-name
                value: ""
            - IS NOT EMPTY:
                field: Vm-created_on
                value: ""
            - and:
              - IS NOT NULL:
                  field: Vm-host_name
                  value: ""
          '

          options = {
            :userid   => @user.userid,
            :only     => ["name", "host_name"],
            :page     => 3,
            :per_page => 2,
            :filter   => filter
          }
          results, attrs = report.paged_view_search(options)
          results.length.should == 2
          results.data.first["name"].should == "Test Group 3 VM 50"
          results.data.last["name"].should == "Test Group 2 VM 40"
          attrs[:apply_sortby_in_search].should be_true
          attrs[:apply_limit_in_sql].should be_false
          attrs[:auth_count].should == 10
          attrs[:user_filters]["managed"].should == [["/managed/environment/prod"], ["/managed/service_level/silver"]]
          attrs[:total_count].should == 100
        end

        it "works when filtering on a virtual reflection" do
          report = MiqReport.new(:db => "Vm", :sortby => ["name"], :order => "Descending")
          filter = YAML.load '--- !ruby/object:MiqExpression
          exp:
            and:
            - IS NOT NULL:
                field: Vm-name
                value: ""
            - and:
              - IS NULL:
                  field: Vm.parent_resource_pool-name
                  value: ""
          '

          options = {
            :only     => ["name"],
            :page     => 2,
            :per_page => 10,
            :filter   => filter
          }
          results, attrs = report.paged_view_search(options)
          results.length.should == 10
          results.data.first["name"].should == "Test Group 4 VM 89"
          results.data.last["name"].should == "Test Group 4 VM 80"
          attrs[:apply_sortby_in_search].should be_true
          attrs[:apply_limit_in_sql].should be_false
          attrs[:auth_count].should == 100
          attrs[:user_filters]["managed"].should be_empty
          attrs[:total_count].should == 100
        end

        it "does not raise errors when virtual columns are included in cols" do
          report = MiqReport.new(
            :name      => "VMs",
            :title     => "Virtual Machines",
            :db        => "Vm",
            :cols      => ["name", "ems_cluster_name", "last_compliance_status", "v_total_snapshots", "last_scan_on"],
            :include   => {"storage" => {"columns" => ["name"]}, "host" => {"columns" => ["name"]}},
            :col_order => ["name", "ems_cluster_name", "host.name", "storage.name", "last_compliance_status", "v_total_snapshots", "last_scan_on"],
            :headers   => ["Name", "Cluster", "Host", "Datastore", "Compliant", "Total Snapshots", "Last Analysis Time"],
            :order     => "Ascending",
            :sortby    => ["name"],
            :group     => "n"
          )
          options = {
            :per_page     => 20,
            :page         => 1,
            :targets_hash => true,
            :userid       => "admin"
          }
          results = attrs = nil
          -> { results, attrs = report.paged_view_search(options) }.should_not raise_error
          results.length.should == 20
          attrs[:total_count].should == 100
        end
      end
    end
  end

  describe "#generate_table" do
    before :each do
      allow(MiqServer).to receive(:my_zone) { "Zone 1" }
      FactoryGirl.create(:time_profile_utc)
    end
    let(:report) do
      MiqReport.new(
        :name     => "All Departments with Performance", :title => "All Departments with Performance for last week",
      :db         => "VmPerformance",
      :cols       => %w(resource_name max_cpu_usage_rate_average cpu_usage_rate_average),
      :include    => {"vm" => {"columns" => ["v_annotation"]}, "host" => {"columns" => ["name"]}},
      :col_order  => ["ems_cluster.name", "vm.v_annotation", "host.name"],
      :headers    => ["Cluster", "VM Annotations - Notes", "Host Name"],
      :order      => "Ascending",
      :group      => "c",
      :db_options => {:start_offset => 604_800, :end_offset => 0, :interval => interval},
      :conditions => conditions)
    end
    context "daily reports" do
      let(:interval) { "daily" }

      context "with conditions where is joining with another table" do
        let(:conditions) do
          YAML.load '--- !ruby/object:MiqExpression
                     exp:
                       IS NOT EMPTY:
                         field: VmPerformance.host-name
                       context_type:'
        end

        it "should not raise an exception" do
          expect do
            report.generate_table(:userid        => "admin",
                                  :mode          => "async",
                                  :report_source => "Requested by user")
          end.not_to raise_error
        end
      end
    end
  end
end
