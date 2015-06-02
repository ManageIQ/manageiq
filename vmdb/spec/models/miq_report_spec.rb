require "spec_helper"

describe MiqReport do
  it "attr_accessors are serializable via yaml" do
    result = [{"id"=>5, "vmm_vendor"=>"VMware", "vmm_product"=>"ESXi", "ipaddress"=>"192.168.252.13", "vmm_buildnumber"=>"260247", "vmm_version"=>"4.1.0", "name"=>"VI4ESXM1.manageiq.com"}, {"id"=>3, "vmm_vendor"=>"VMware", "vmm_product"=>"ESXi", "ipaddress"=>"192.168.252.9", "vmm_buildnumber"=>"348481", "vmm_version"=>"4.1.0", "name"=>"vi4esxm2.manageiq.com"}, {"id"=>4, "vmm_vendor"=>"VMware", "vmm_product"=>"ESX", "ipaddress"=>"192.168.252.10", "vmm_buildnumber"=>"502767", "vmm_version"=>"4.1.0", "name"=>"vi4esxm3.manageiq.com"}, {"id"=>1, "vmm_vendor"=>"VMware", "vmm_product"=>"ESXi", "ipaddress"=>"192.168.252.4", "vmm_buildnumber"=>"504850", "vmm_version"=>"4.0.0", "name"=>"per410a-t5.manageiq.com"}]
    column_names = ["name", "ipaddress", "vmm_vendor", "vmm_product", "vmm_version", "vmm_buildnumber", "id"]
    fake_ruport_data_table = { :data => result, :column_names => column_names }
    before = MiqReport.new
    before.table = fake_ruport_data_table
    after = YAML.load(YAML.dump(before))
    after.table.should == fake_ruport_data_table
  end

  context "#paged_view_search_gp" do
    before(:each) do
      MiqRegion.seed

      # Create EVM tables/indexes and hourly metric data...
      @table_1    = FactoryGirl.create(:vmdb_table_evm,  :name => "accounts")
      @index_1    = FactoryGirl.create(:vmdb_index,      :name => "accounts_pkey", :vmdb_table => @table_1)
      @metric_1A  = FactoryGirl.create(:vmdb_metric, :resource => @index_1, :timestamp => 2.hours.ago.utc, :capture_interval_name => 'hourly', :size => 100, :rows => 100, :pages => 100, :wasted_bytes => 100, :percent_bloat => 100)
      @metric_1B  = FactoryGirl.create(:vmdb_metric, :resource => @index_1, :timestamp => 1.hour.ago.utc,  :capture_interval_name => 'hourly', :size => 101, :rows => 101, :pages => 101, :wasted_bytes => 101, :percent_bloat => 101)
      @metric_1C  = FactoryGirl.create(:vmdb_metric, :resource => @index_1, :timestamp => Time.now.utc,    :capture_interval_name => 'hourly', :size => 102, :rows => 102, :pages => 102, :wasted_bytes => 102, :percent_bloat => 102)

      @table_2    = FactoryGirl.create(:vmdb_table_evm,  :name => "advanced_settings")
      @index_2    = FactoryGirl.create(:vmdb_index,      :name => "advanced_settings_pkey", :vmdb_table => @table_2)
      @metric_2A  = FactoryGirl.create(:vmdb_metric, :resource => @index_2, :timestamp => 2.hours.ago.utc, :capture_interval_name => 'hourly', :size => 200, :rows => 200, :pages => 200, :wasted_bytes => 200, :percent_bloat => 200)
      @metric_2B  = FactoryGirl.create(:vmdb_metric, :resource => @index_2, :timestamp => 1.hour.ago.utc,  :capture_interval_name => 'hourly', :size => 201, :rows => 201, :pages => 201, :wasted_bytes => 201, :percent_bloat => 201)
      @metric_2C  = FactoryGirl.create(:vmdb_metric, :resource => @index_2, :timestamp => Time.now.utc,    :capture_interval_name => 'hourly', :size => 202, :rows => 202, :pages => 202, :wasted_bytes => 202, :percent_bloat => 202)

      @table_3    = FactoryGirl.create(:vmdb_table_evm,  :name => "assigned_server_roles")
      @index_3    = FactoryGirl.create(:vmdb_index,      :name => "assigned_server_roles_pkey", :vmdb_table => @table_3)
      @metric_3A  = FactoryGirl.create(:vmdb_metric, :resource => @index_3, :timestamp => 2.hours.ago.utc, :capture_interval_name => 'hourly', :size => 300, :rows => 300, :pages => 300, :wasted_bytes => 300, :percent_bloat => 300)
      @metric_3B  = FactoryGirl.create(:vmdb_metric, :resource => @index_3, :timestamp => 1.hour.ago.utc,  :capture_interval_name => 'hourly', :size => 301, :rows => 301, :pages => 301, :wasted_bytes => 301, :percent_bloat => 301)
      @metric_3C  = FactoryGirl.create(:vmdb_metric, :resource => @index_3, :timestamp => Time.now.utc,    :capture_interval_name => 'hourly', :size => 302, :rows => 302, :pages => 302, :wasted_bytes => 302, :percent_bloat => 302)

      @index_3A   = FactoryGirl.create(:vmdb_index,      :name => "assigned_server_roles_idx", :vmdb_table => @table_3)
      @metric_3AA = FactoryGirl.create(:vmdb_metric, :resource => @index_3A, :timestamp => 2.hour.ago.utc, :capture_interval_name => 'hourly', :size => 310, :rows => 310, :pages => 310, :wasted_bytes => 310, :percent_bloat => 310)
      @metric_3AB = FactoryGirl.create(:vmdb_metric, :resource => @index_3A, :timestamp => 1.hour.ago.utc, :capture_interval_name => 'hourly', :size => 311, :rows => 311, :pages => 311, :wasted_bytes => 311, :percent_bloat => 311)
      @metric_3AC = FactoryGirl.create(:vmdb_metric, :resource => @index_3A, :timestamp => Time.now.utc,   :capture_interval_name => 'hourly', :size => 312, :rows => 312, :pages => 312, :wasted_bytes => 312, :percent_bloat => 312)

      @report_args = {
        "title"       => "VmdbIndex",
        "name"        => "VmdbIndex",
        "db"          => "VmdbIndex",
        "cols"        => ["name"],
        "include"     => {"vmdb_table" => {"columns" => ["type"]}, "latest_hourly_metric" => {"columns"=>["rows", "size", "wasted_bytes", "percent_bloat"]}},
        "col_order"   => ["name", "latest_hourly_metric.rows", "latest_hourly_metric.size", "latest_hourly_metric.wasted_bytes", "latest_hourly_metric.percent_bloat"],
        "col_formats" => [nil, nil, :bytes_human, :bytes_human, nil],
        "headers"     => ["Name", "Rows", "Size", "Wasted", "Percent Bloat"],
        "order"       => "Ascending",
        "sortby"      => ["name"],
        "group"       => "n",
      }

      @search_expression  = MiqExpression.new({"and" => [{"=" => {"value" => "VmdbTableEvm", "field" => "VmdbIndex.vmdb_table-type"}}]})

    end

    describe 'self.get_expressions_by_model' do
      it 'it returns only reports with non-nil conditions' do

        test_group = FactoryGirl.create(:miq_group)
        rep_null = FactoryGirl.create(:miq_report_with_null_condition)

        rep_nil  = FactoryGirl.create(:miq_report_wo_null_but_nil_condition)
        # FIXME: find a way to do this in a factory
        crap = "--- !!null \n...\n"
        ActiveRecord::Base.connection.execute("update miq_reports set conditions='#{crap}' where id=#{rep_nil.id}")

        rep_ok   = FactoryGirl.create(:miq_report_with_non_nil_condition)

        reports = MiqReport.get_expressions_by_model('Vm')

        reports.should be_kind_of(Hash)
        reports.count.should == 1
        reports.find { |report| report[0] == rep_null.name }.should be_nil
        reports.find { |report| report[0] == rep_nil.name }.should be_nil
        reports.find { |report| report[0] == rep_ok.name }.should_not be_nil
      end
    end


    it "reports on EVM table indexes and metrics properly" do

      report = MiqReport.new(@report_args)

      search_expression  = MiqExpression.new({"and" => [{"=" => {"value" => "VmdbTableEvm", "field" => "VmdbIndex.vmdb_table-type"}}]})

      options = { :targets_hash   => true,
                  :filter         => search_expression,
                  :page           => 1,
                  :per_page       => 20
      }

      results, attrs = report.paged_view_search(options)
      results.count.should be 4
    end
  end

  context "#paged_view_search" do
    OS_LIST = %w{_none_ windows ubuntu windows ubuntu}

    before(:each) do
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
          vm.hardware = FactoryGirl.build(:hardware, :numvcpus => (group * 2), :memory_cpu => (group * 1.megabytes), :guest_os => OS_LIST[group])
          vm.host = @hosts[group-1]
          vm.evm_owner_id = @user.id  if ((i % 5) == 0)
          vm.miq_group_id = @group.id if ((i % 7) == 0)
          vm.save
          tags = []
          @tags.each { |n,t| tags << t if (i % n) == 0 }
          vm.tag_with(tags.join(" "), :ns => "*") unless tags.empty?
        end

        10.times do |i|
          FactoryGirl.create(:ems_event, :timestamp => Time.now.utc, :message => "Event #{i}")
        end

        Vm.scope :group_3_scope, :conditions => ["name LIKE ?", "Test Group 3%"]
        Vm.scope :group_scope,   lambda { |group_num| {:conditions => ["name LIKE ?", "Test Group #{group_num}%"]} }
      end

      context "in folders" do
        before(:each) do
          ems1 = FactoryGirl.create(:ems_vmware, :name => 'ems1')
          @hosts.each { |host| host.update_attributes(:ext_management_system => ems1) }

          @root          = FactoryGirl.create(:ems_folder, :name => "Datacenters")
          @root.parent   = ems1
          @root.save
          @sl            = FactoryGirl.create(:ems_folder, :name => "ServiceLevel")
          @sl.parent     = @root
          @sl.save
          @silver        = FactoryGirl.create(:ems_folder, :name => "Silver")
          @silver.parent = @sl
          @silver.save

          @vms_in_silver_folder = Vm.find_tagged_with(:any => "/managed/service_level/silver", :ns => "*")
          @vms_in_silver_folder.each do |vm|
            vm.with_relationship_type("ems_metadata") { vm.parent = @silver }
          end
        end

        it "filters properly" do
          report = MiqReport.new(:db => "Vm", :sortby => "name", :order => "Descending")
          options = {:page => nil, :per_page => nil, :parent => @sl } # Get all pages

          results, attrs = report.paged_view_search(options)
          found_ids = results.data.collect { |rec| rec.data['id'] }
          found_ids.should be_empty

          options[:association] = :all_vms
          results, attrs = report.paged_view_search(options)
          found_ids = results.data.collect { |rec| rec.data['id'] }
          found_ids.should match_array(@vms_in_silver_folder.collect(&:id))
        end
      end

      context "group has managed filters" do
        before(:each) do
          User.stub(:server_timezone => "UTC")
          @group.update_attributes(:filters => {"managed"=>[["/managed/environment/prod"], ["/managed/service_level/silver"]], "belongsto"=>[]})
        end

        it "works when page parameters are passed" do
          report = MiqReport.new(:db => "Vm", :sortby => "name", :order => "Descending")
          options = {
            :only     => ["name"],
            :page     => 2,
            :per_page => 10
          }
          results, attrs = report.paged_view_search(options)
          # results.data.each {|r| $log.info("XXX: result: #{r["name"]}")}
          results.length.should == 10
          results.data.first["name"].should == "Test Group 4 VM 89"
          results.data.last["name"].should  == "Test Group 4 VM 80"
          report.table.length.should == 10
          report.table.data.first["name"].should == "Test Group 4 VM 89"
          report.table.data.last["name"].should  == "Test Group 4 VM 80"
          attrs[:apply_sortby_in_search].should be_true
          attrs[:apply_limit_in_sql].should be_true
          attrs[:auth_count].should == 100
          attrs[:user_filters]["managed"].should be_empty
          attrs[:total_count].should == 100
        end

        it "works when page parameters and user filters are passed" do
          report = MiqReport.new(:db => "Vm", :sortby => "name", :order => "Descending")
          options = {
            :only     => ["name"],
            :userid   => @user.userid,
          }
          results, attrs = report.paged_view_search(options)
          # results.data.each {|r| $log.info("XXX: result: #{r["name"]}")}
          results.length.should == 10
          results.data.first["name"].should == "Test Group 4 VM 90"
          results.data.last["name"].should  == "Test Group 1 VM 0"
          report.table.length.should == 10
          attrs[:apply_sortby_in_search].should be_true
          attrs[:apply_limit_in_sql].should be_true
          attrs[:auth_count].should == 10
          attrs[:user_filters]["managed"].should == [["/managed/environment/prod"], ["/managed/service_level/silver"]]
          attrs[:total_count].should == 100

          report = MiqReport.new(:db => "Vm", :sortby => "name", :order => "Descending")
          options = {
            :only     => ["name"],
            :userid   => @user.userid,
            :page     => 3,
            :per_page => 2
          }
          results, attrs = report.paged_view_search(options)
          # results.data.each {|r| $log.info("XXX: result: #{r["name"]}")}
          results.length.should == 2
          results.data.first["name"].should == "Test Group 3 VM 50"
          results.data.last["name"].should  == "Test Group 2 VM 40"
          report.table.length.should == 2
          attrs[:apply_sortby_in_search].should be_true
          attrs[:apply_limit_in_sql].should be_true
          attrs[:auth_count].should == 10
          attrs[:user_filters]["managed"].should == [["/managed/environment/prod"], ["/managed/service_level/silver"]]
          attrs[:total_count].should == 100
        end

        it "works when page parameters and user filters are passed and sort column is in a sub-table" do
          report = MiqReport.new(:db => "Vm", :sortby => ["storage.name", "name"], :order => "Descending", :include => {"storage"=>{"columns"=>["name"]}})
          options = {
            :only     => ["name", "storage.name"],
            :userid   => @user.userid,
          }
          results, attrs = report.paged_view_search(options)
          # results.data.each {|r| $log.info("XXX: result: #{r["name"]}")}
          results.length.should == 10
          results.data.first["name"].should == "Test Group 4 VM 90"
          results.data.last["name"].should  == "Test Group 1 VM 0"
          report.table.length.should == 10
          attrs[:apply_sortby_in_search].should be_true
          attrs[:apply_limit_in_sql].should be_true
          attrs[:auth_count].should == 10
          attrs[:user_filters]["managed"].should == [["/managed/environment/prod"], ["/managed/service_level/silver"]]
          attrs[:total_count].should == 100
        end

        it "works when sorting on a virtual column" do
          @group.update_attributes(:filters => {"managed"=>[["/managed/environment/prod"], ["/managed/service_level/silver"]], "belongsto"=>[]})
          # Vm.any_instance.stub(:v_total_snapshots => 1)
          report = MiqReport.new(:db => "Vm", :sortby => ["v_total_snapshots", "name"], :order => "Descending")
          # report = MiqReport.new(:db => "Vm", :sortby => ["name"], :order => "Descending")
          options = {
            :only     => ["name", "v_total_snapshots"],
            :page     => 2,
            :per_page => 10
          }
          results, attrs = report.paged_view_search(options)
          # results.data.each {|r| $log.info("XXX: result: #{r["name"]}")}
          results.length.should == 10
          results.data.first["name"].should == "Test Group 4 VM 89"
          results.data.last["name"].should  == "Test Group 4 VM 80"
          report.table.length.should == 10
          report.table.data.first["name"].should == "Test Group 4 VM 89"
          report.table.data.last["name"].should  == "Test Group 4 VM 80"
          attrs[:apply_sortby_in_search].should be_false
          attrs[:apply_limit_in_sql].should be_true
          attrs[:auth_count].should == 100
          attrs[:user_filters]["managed"].should be_empty
          attrs[:total_count].should == 100
        end

        it "works when sorting on a column in a sub-table" do
          report = MiqReport.new(:db => "Vm", :cols => ["name", "host.name"], :include => {"host"=>{"columns"=>["name"]}}, :sortby => ["host.name", "name"], :order => "Descending")
          options = {
            :only     => ["name", "host.name"],
            :page     => 2,
            :per_page => 10
          }
          results, attrs = report.paged_view_search(options)
          # results.data.each {|r| $log.info("XXX: result: #{r["host.name"]} => #{r["name"]}")}
          results.length.should == 10
          results.data.first["name"].should == "Test Group 1 VM 21"
          results.data.last["name"].should  == "Test Group 1 VM 13"
          attrs[:apply_sortby_in_search].should be_true
          attrs[:apply_limit_in_sql].should be_true
          attrs[:auth_count].should == 100
          attrs[:user_filters]["managed"].should be_empty
          attrs[:total_count].should == 100

          report = MiqReport.new(:db => "Vm", :include_for_find => {:hardware => {}}, :include => {"hardware"=>{"columns"=>["guest_os"]}}, :sortby => ["hardware.guest_os", "name"], :order => "Descending")
          options = {
            :only     => ["name", "hardware.guest_os"],
            :page     => 2,
            :per_page => 10
          }
          results, attrs = report.paged_view_search(options)
          # results.data.each {|r| $log.info("XXX: result: #{r["host.name"]} => #{r["name"]}")}
          results.length.should == 10
          results.data.first["name"].should == "Test Group 4 VM 89"
          results.data.last["name"].should  == "Test Group 4 VM 80"
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
          # results.data.each {|r| $log.info("XXX: result: #{r["name"]}")}
          results.length.should == 10
          results.data.first["name"].should == "Test Group 1 VM 18"
          results.data.last["name"].should  == "Test Group 1 VM 4"
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
          # results.data.each {|r| $log.info("XXX: result: #{r["name"]}")}
          results.length.should == 2
          results.data.first["name"].should == "Test Group 3 VM 50"
          results.data.last["name"].should  == "Test Group 2 VM 40"
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
          # results.data.each {|r| $log.info("XXX: result: #{r["name"]}")}
          results.length.should == 10
          results.data.first["name"].should == "Test Group 4 VM 89"
          results.data.last["name"].should  == "Test Group 4 VM 80"
          attrs[:apply_sortby_in_search].should be_true
          attrs[:apply_limit_in_sql].should be_false
          attrs[:auth_count].should == 100
          attrs[:user_filters]["managed"].should be_empty
          attrs[:total_count].should == 100
        end

        it "does not raise errors when virtual columns are included in cols" do
          report = MiqReport.new(
            :name       => "VMs",
            :title      => "Virtual Machines",
            :db         => "Vm",
            :cols       => ["name", "ems_cluster_name", "last_compliance_status", "v_total_snapshots", "last_scan_on"],
            :include    => {"storage"=>{"columns"=>["name"]}, "host"=>{"columns"=>["name"]}},
            :col_order  => ["name", "ems_cluster_name", "host.name", "storage.name", "last_compliance_status", "v_total_snapshots", "last_scan_on"],
            :headers    => ["Name", "Cluster", "Host", "Datastore", "Compliant", "Total Snapshots", "Last Analysis Time"],
            :order      => "Ascending",
            :sortby     => ["name"],
            :group      => "n"
          )
          options = {
           :per_page    =>20,
           :page        =>1,
           :targets_hash=>true,
           :userid      =>"admin"
          }
          results = attrs = nil
          lambda { results, attrs = report.paged_view_search(options) }.should_not raise_error
          results.length.should == 20
          attrs[:total_count].should == 100
        end
      end

      context "with a parent and an association" do
        before(:each) do
          @host = @hosts.first
        end

        it "returns the correct number of VMs under Host in the correct order" do
          report = MiqReport.new(:db => "Vm", :sortby => "name", :order => "Descending")
          options = {
            :parent   => @host,
            :association => "vms",
            :only     => ["name"],
            :page     => 2,
            :per_page => 10
          }
          results, attrs = report.paged_view_search(options)
          # results.data.each {|r| $log.info("XXX: result: #{r["name"]}")}
          results.length.should == 10
          results.data.first["name"].should == "Test Group 1 VM 21"
          results.data.last["name"].should  == "Test Group 1 VM 13"
          attrs[:apply_sortby_in_search].should be_true
          attrs[:apply_limit_in_sql].should be_true
          attrs[:auth_count].should == 25
          attrs[:user_filters]["managed"].should be_empty
          attrs[:total_count].should == 25
        end
      end
    end

    # it "should handle ActAsArModel through find" do
    #   MiqDatabase.seed
    #   options = {
    #     :per_page    =>20,
    #     :page        =>1,
    #     :targets_hash=>true,
    #     :userid      =>"admin"
    #   }

    #   yaml = YAML.load("---
    #     title: VmdbTable
    #     name: VmdbTable
    #     db: VmdbTable
    #     cols:
    #     - name
    #     - description
    #     - record_count
    #     col_order:
    #     - name
    #     - description
    #     - record_count
    #     headers:
    #     - Name
    #     - Description
    #     - Record Count
    #     order: Ascending
    #     sortby:
    #     - description
    #   ")
    #   begin
    #     report = MiqReport.new(yaml)
    #     results = attrs = nil
    #     lambda { results, attrs = report.paged_view_search(options) }.should_not raise_error
    #     results.length.should == 20
    #     attrs[:total_count].should > 0
    #     attrs[:apply_sortby_in_search].should be_false

    #     # Retrieve page 2
    #     results = attrs = nil
    #     lambda { results, attrs = report.paged_view_search(options.merge({:page => 2 }))}.should_not raise_error
    #     results.length.should == 20
    #     attrs[:total_count].should > 0
    #     attrs[:apply_sortby_in_search].should be_false
    #   ensure
    #     VmdbTable.registered.clear
    #   end
    # end
  end
end
