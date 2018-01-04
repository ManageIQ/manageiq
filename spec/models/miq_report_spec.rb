shared_examples "custom_report_with_custom_attributes" do |base_report, custom_attribute_field|
  let(:options) { {:targets_hash => true, :userid => "admin"} }
  let(:custom_attributes_field) { custom_attribute_field.to_s.pluralize }

  before do
    @user = FactoryGirl.create(:user_with_group)

    # create custom attributes
    @key    = 'key1'
    @value  = 'value1'

    @resource = base_report == "Host" ? FactoryGirl.create(:host) : FactoryGirl.create(:vm_vmware)
    FactoryGirl.create(custom_attribute_field, :resource => @resource, :name => @key, :value => @value)
  end

  let(:report) do
    MiqReport.new(
      :name      => "Custom VM report",
      :title     => "Custom VM report",
      :rpt_group => "Custom",
      :rpt_type  => "Custom",
      :db        => base_report == "Host" ? "Host" : "ManageIQ::Providers::InfraManager::Vm",
      :cols      => %w(name),
      :include   => {custom_attributes_field.to_s => {"columns" => %w(name value)}},
      :col_order => %w(miq_custom_attributes.name miq_custom_attributes.value name),
      :headers   => ["EVM Custom Attribute Name", "EVM Custom Attribute Value", "Name"],
      :order     => "Ascending",
      :sortby    => ["miq_custom_attributes.name"]
    )
  end

  it "creates custom report based on #{base_report} with #{custom_attribute_field} field of custom attributes" do
    expect { @results, _attrs = report.paged_view_search(options) }.not_to raise_error

    custom_attributes_name = "#{custom_attributes_field}.name"
    custom_attributes_value = "#{custom_attributes_field}.value"
    expect(@results.data.first[custom_attributes_name]).to eq(@key)
    expect(@results.data.first[custom_attributes_value]).to eq(@value)
  end
end

describe MiqReport do
  context ".for_user" do
    let(:my_user) { FactoryGirl.create(:user_with_group) }
    let(:group_in_my_tenant) { FactoryGirl.create(:miq_group, :tenant => my_user.current_tenant) }

    let(:other_tenant) { FactoryGirl.create(:tenant) }
    let(:group_in_other_tenant) { FactoryGirl.create(:miq_group, :tenant => other_tenant) }

    let!(:my_report) { FactoryGirl.create(:miq_report, :miq_group => my_user.current_group, :rpt_type => "Custom") }
    let!(:report_in_my_tenant) { FactoryGirl.create(:miq_report, :miq_group => group_in_my_tenant, :rpt_type => "Custom") }
    let!(:report_in_another_tenant) { FactoryGirl.create(:miq_report, :miq_group => group_in_other_tenant, :rpt_type => "Custom") }

    it "returns reports created by me or anyone in a group in my tenant" do
      User.current_user = my_user

      expect(described_class.for_user(my_user)).to match_array([my_report, report_in_my_tenant])
    end
  end

  context "report with filtering in Registry" do
    let(:options)  { {:targets_hash => true, :userid => "admin"} }
    let(:miq_task) { FactoryGirl.create(:miq_task) }

    before do
      @user     = FactoryGirl.create(:user_with_group)

      @registry = FactoryGirl.create(:registry_item, :name => "HKLM\\SOFTWARE\\WindowsFirewall : EnableFirewall",
                                                     :data => 0)
      @vm       = FactoryGirl.create(:vm_vmware, :registry_items => [@registry])
      EvmSpecHelper.local_miq_server
    end

    let(:report) do
      MiqReport.new(:name => "Custom VM report", :title => "Custom VM report", :rpt_group => "Custom",
        :rpt_type => "Custom", :db => "Vm", :cols => %w(name),
        :conditions => MiqExpression.new("=" => {"regkey" => "HKLM\\SOFTWARE\\WindowsFirewall",
                                                 "regval" => "EnableFirewall", "value" => "0"}),
        :include   => {"registry_items" => {"columns" => %w(data name value_name)}},
        :col_order => %w(name registry_items.data registry_items.name registry_items.value_name),
        :headers   => ["Name", "Registry Data", "Registry Name", "Registry Value Name"],
        :order     => "Ascending")
    end

    it "can generate a report filtered by registry items" do
      report.queue_generate_table(:userid => @user.userid)
      report._async_generate_table(miq_task.id, :userid => @user.userid, :mode => "async",
                                   :report_source => "Requested by user")

      report_result = report.table.data.map do |x|
        x.data.delete("id")
        x.data
      end

      expect(report_result.count).to eq(1)
      expect(report_result.first["name"]).to eq(@vm.name)
    end
  end

  context "report with virtual dynamic custom attributes" do
    let(:options)              { {:targets_hash => true, :userid => "admin"} }
    let(:custom_column_key_1)  { 'kubernetes.io/hostname' }
    let(:custom_column_key_2)  { 'manageiq.org' }
    let(:custom_column_key_3)  { 'ATTR_Name_3' }
    let(:custom_column_value)  { 'value1' }
    let(:user)                 { FactoryGirl.create(:user_with_group) }
    let(:ems)                  { FactoryGirl.create(:ems_vmware) }
    let!(:vm_1)                { FactoryGirl.create(:vm_vmware) }
    let!(:vm_2)                { FactoryGirl.create(:vm_vmware, :retired => false, :ext_management_system => ems) }
    let(:virtual_column_key_1) { "#{CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX}kubernetes.io/hostname" }
    let(:virtual_column_key_2) { "#{CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX}manageiq.org" }
    let(:virtual_column_key_3) { "#{CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX}ATTR_Name_3" }
    let(:miq_task)             { FactoryGirl.create(:miq_task) }

    subject! do
      FactoryGirl.create(:miq_custom_attribute, :resource => vm_1, :name => custom_column_key_1,
                         :value => custom_column_value)
      FactoryGirl.create(:miq_custom_attribute, :resource => vm_2, :name => custom_column_key_2,
                         :value => custom_column_value)
      FactoryGirl.create(:miq_custom_attribute, :resource => vm_2, :name => custom_column_key_3,
                         :value => custom_column_value)
    end

    before do
      EvmSpecHelper.local_miq_server
    end

    let(:report) do
      MiqReport.new(
        :name => "Custom VM report", :title => "Custom VM report", :rpt_group => "Custom", :rpt_type => "Custom",
        :db        => "ManageIQ::Providers::InfraManager::Vm",
        :cols      => %w(name virtual_custom_attribute_kubernetes.io/hostname virtual_custom_attribute_manageiq.org),
        :include   => {:custom_attributes => {}},
        :col_order => %w(name virtual_custom_attribute_kubernetes.io/hostname virtual_custom_attribute_manageiq.org),
        :headers   => ["Name", custom_column_key_1, custom_column_key_1],
        :order     => "Ascending"
      )
    end

    context 'with container images' do
      let(:report) do
        MiqReport.new(
          :name => "Custom VM report", :title => "Custom VM report", :rpt_group => "Custom", :rpt_type => "Custom",
            :db        => "ContainerImage",
            :cols      => ['name',
                           "virtual_custom_attribute_CATTR#{CustomAttributeMixin::SECTION_SEPARATOR}docker_labels",
                           "virtual_custom_attribute_CATTR#{CustomAttributeMixin::SECTION_SEPARATOR}labels"],
            :include   => {:custom_attributes => {}},
            :col_order => %w(name CATTR),
            :headers   => ["Name", custom_column_key_1, custom_column_key_1],
            :order     => "Ascending"
        )
      end

      let!(:container_image) do
        FactoryGirl.create(:container_image, :name => "test_container_images")
      end

      let!(:custom_attribute_1) do
        FactoryGirl.create(:custom_attribute, :resource => container_image, :name => 'CATTR', :value => 'any_value',
                           :section => 'docker_labels')
      end

      let!(:custom_attribute_2) do
        FactoryGirl.create(:custom_attribute, :resource => container_image, :name => 'CATTR', :value => 'other_value',
                           :section => 'labels')
      end

      it "generates report with dynamic custom attributes" do
        report.queue_generate_table(:userid => user.userid)
        report._async_generate_table(miq_task.id, :userid => user.userid, :mode => "async",
                                     :report_source => "Requested by user")

        report_result = report.table.data.map do |x|
          x.data.delete("id")
          x.data
        end

        expected_results = [
          {"name"                                                                                  => "test_container_images",
           "virtual_custom_attribute_CATTR#{CustomAttributeMixin::SECTION_SEPARATOR}docker_labels" => "any_value",
           "virtual_custom_attribute_CATTR#{CustomAttributeMixin::SECTION_SEPARATOR}labels"        => "other_value"}
        ]

        expect(report_result).to match_array(expected_results)
      end
    end

    it "generates report with dynamic custom attributes" do
      report.queue_generate_table(:userid => user.userid)
      report._async_generate_table(miq_task.id, :userid => user.userid, :mode => "async",
                                                :report_source => "Requested by user")

      report_result = report.table.data.map do |x|
        x.data.delete("id")
        x.data
      end
      expected_results = [{"name" => vm_1.name, virtual_column_key_1 => custom_column_value,
                           virtual_column_key_2 => nil},
                          {"name" => vm_2.name, virtual_column_key_1 => nil,
                           virtual_column_key_2 => custom_column_value}]

      expect(report_result).to match_array(expected_results)
    end

    let(:exp) { MiqExpression.new("IS NOT EMPTY" => {"field" => "#{vm_1.type}-#{virtual_column_key_1}"}) }

    it "generates report with dynamic custom attributes with MiqExpression filtering" do
      report.conditions = exp

      report.queue_generate_table(:userid => user.userid)
      report._async_generate_table(miq_task.id, :userid => user.userid, :mode => "async",
                                                :report_source => "Requested by user")

      report_result = report.table.data.map do |x|
        x.data.delete("id")
        x.data
      end

      expected_results = ["name" => vm_1.name, virtual_column_key_1 => custom_column_value, virtual_column_key_2 => nil]

      expect(report_result).to match_array(expected_results)
    end

    let(:exp_3) do
      MiqExpression.new("and" => [{"=" => { "field" => "#{vm_2.type}-active", "value" => "true"}},
                                  {"or" => [{"IS NOT EMPTY" => { "field" => "#{vm_2.type}-name", "value" => ""}},
                                            {"IS NOT EMPTY" => { "field" => "#{vm_2.type}-#{virtual_column_key_3}"}}]}])
    end

    it "generates report with dynamic custom attributes with filtering with field which is not listed in cols" do
      report.conditions = exp_3
      report.queue_generate_table(:userid => user.userid)
      report._async_generate_table(miq_task.id, :userid => user.userid, :mode => "async",
                                   :report_source => "Requested by user")

      report_result = report.table.data.map do |x|
        x.data.delete("id")
        x.data
      end

      expected_results = ["name" => vm_2.name, virtual_column_key_1 => nil, virtual_column_key_2 => custom_column_value]

      expect(report_result).to match_array(expected_results)
    end
  end

  context "Host and MiqCustomAttributes" do
    include_examples "custom_report_with_custom_attributes", "Host", :miq_custom_attribute
  end

  context "Vm and MiqCustomAttributes" do
    include_examples "custom_report_with_custom_attributes", "Vm", :miq_custom_attribute
  end

  context "Host and EmsCustomAttributes" do
    include_examples "custom_report_with_custom_attributes", "Host", :ems_custom_attribute
  end

  context "Vm and EmsCustomAttributes" do
    include_examples "custom_report_with_custom_attributes", "Vm", :ems_custom_attribute
  end

  it "attr_accessors are serializable via yaml" do
    result = [{"id" => 5, "vmm_vendor" => "vmware", "vmm_vendor_display" => "VMware", "vmm_product" => "ESXi", "ipaddress" => "192.168.252.13", "vmm_buildnumber" => "260247", "vmm_version" => "4.1.0", "name" => "VI4ESXM1.manageiq.com"}, {"id" => 3, "vmm_vendor" => "VMware", "vmm_product" => "ESXi", "ipaddress" => "192.168.252.9", "vmm_buildnumber" => "348481", "vmm_version" => "4.1.0", "name" => "vi4esxm2.manageiq.com"}, {"id" => 4, "vmm_vendor" => "VMware", "vmm_product" => "ESX", "ipaddress" => "192.168.252.10", "vmm_buildnumber" => "502767", "vmm_version" => "4.1.0", "name" => "vi4esxm3.manageiq.com"}, {"id" => 1, "vmm_vendor" => "VMware", "vmm_product" => "ESXi", "ipaddress" => "192.168.252.4", "vmm_buildnumber" => "504850", "vmm_version" => "4.0.0", "name" => "per410a-t5.manageiq.com"}]
    column_names = ["name", "ipaddress", "vmm_vendor", "vmm_vendor_display", "vmm_product", "vmm_version", "vmm_buildnumber", "id"]
    fake_ruport_data_table = {:data => result, :column_names => column_names}
    before = MiqReport.new
    before.table = fake_ruport_data_table
    after = YAML.load(YAML.dump(before))
    expect(after.table).to eq(fake_ruport_data_table)
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
    it "filters vms in folders" do
      host = FactoryGirl.create(:host)
      vm1  = FactoryGirl.create(:vm_vmware, :host => host)
      allow(vm1).to receive(:archived?).and_return(false)
      vm2  = FactoryGirl.create(:vm_vmware, :host => host)
      allow(vm2).to receive(:archived?).and_return(false)
      allow(Vm).to receive(:find_by).and_return(vm1)

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

      ems   = FactoryGirl.create(:ems_vmware)
      host2 = FactoryGirl.create(:host)
      vmb   = FactoryGirl.create(:vm_vmware, :host => host2, :name => "b", :ext_management_system => ems)
      vmc   = FactoryGirl.create(:vm_vmware, :host => host2, :name => "c", :ext_management_system => ems)

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
      vm1 = FactoryGirl.create(:vm_vmware)
      vm1.tag_with("/managed/environment/prod", :ns => "*")
      vm2 = FactoryGirl.create(:vm_vmware)
      vm2.tag_with("/managed/environment/dev", :ns => "*")

      user  = FactoryGirl.create(:user_with_group)
      group = user.current_group
      allow(User).to receive_messages(:server_timezone => "UTC")
      group.entitlement = Entitlement.new
      group.entitlement.set_managed_filters([["/managed/environment/prod"]])
      group.save!

      report = MiqReport.new(:db => "Vm")
      results, attrs = report.paged_view_search(
        :only   => ["name"],
        :userid => user.userid,
      )
      expect(results.length).to eq 1
      expect(results.data.collect(&:name)).to eq [vm1.name]
      expect(report.table.length).to eq 1
      expect(attrs[:apply_sortby_in_search]).to be_truthy
      expect(attrs[:apply_limit_in_sql]).to be_truthy
      expect(attrs[:auth_count]).to eq 1
      expect(attrs[:user_filters]["managed"]).to eq [["/managed/environment/prod"]]
    end

    it "sortby, order, user filters, where sort column is in a sub-table" do
      user  = FactoryGirl.create(:user_with_group)
      group = user.current_group
      vm1 = FactoryGirl.create(:vm_vmware, :name => "VA", :storage => FactoryGirl.create(:storage, :name => "SA"))
      vm2 = FactoryGirl.create(:vm_vmware, :name => "VB", :storage => FactoryGirl.create(:storage, :name => "SB"))
      tag = "/managed/environment/prod"
      group.entitlement = Entitlement.new
      group.entitlement.set_managed_filters([[tag]])
      group.save!
      vm1.tag_with(tag, :ns => "*")
      vm2.tag_with(tag, :ns => "*")

      allow(User).to receive_messages(:server_timezone => "UTC")
      report = MiqReport.new(:db => "Vm", :sortby => %w(storage.name name), :order => "Ascending", :include => {"storage" => {"columns" => ["name"]}})
      options = {
        :only   => ["name", "storage.name"],
        :userid => user.userid,
      }

      results, attrs = report.paged_view_search(options)

      # Why do we need to check all of these things?
      expect(results.length).to eq 2
      expect(results.data.first["name"]).to eq "VA"
      expect(results.data.first["storage.name"]).to eq "SA"
      expect(report.table.length).to eq 2
      expect(attrs[:apply_sortby_in_search]).to be_truthy
      expect(attrs[:apply_limit_in_sql]).to be_truthy
      expect(attrs[:auth_count]).to eq 2
      expect(attrs[:user_filters]["managed"]).to eq [[tag]]
    end

    it "sorting on a virtual column" do
      FactoryGirl.create(:vm_vmware, :name => "B", :host => FactoryGirl.create(:host, :name => "A"))
      FactoryGirl.create(:vm_vmware, :name => "A", :host => FactoryGirl.create(:host, :name => "B"))

      report = MiqReport.new(:db => "Vm", :sortby => %w(host_name name), :order => "Descending")
      options = {
        :only => %w(name host_name),
        :page => 2,
      }

      results, _attrs = report.paged_view_search(options)
      expect(results.length).to eq 2
      expect(results.data.first["host_name"]).to eq "B"
    end

    it "expression filtering on a virtual column" do
      FactoryGirl.create(:vm_vmware, :name => "VA", :host => FactoryGirl.create(:host, :name => "HA"))
      FactoryGirl.create(:vm_vmware, :name => "VB", :host => FactoryGirl.create(:host, :name => "HB"))

      report = MiqReport.new(:db => "Vm")

      filter = YAML.load '--- !ruby/object:MiqExpression
      exp:
        "=":
          field: Vm-host_name
          value: "HA"
      '

      results, _attrs = report.paged_view_search(:only => %w(name host_name), :filter => filter)
      expect(results.length).to eq 1
      expect(results.data.first["name"]).to eq "VA"
      expect(results.data.first["host_name"]).to eq "HA"
    end

    it "expression filtering on a virtual column and user filters" do
      user  = FactoryGirl.create(:user_with_group)
      group = user.current_group

      _vm1 = FactoryGirl.create(:vm_vmware, :name => "VA",  :host => FactoryGirl.create(:host, :name => "HA"))
      vm2 =  FactoryGirl.create(:vm_vmware, :name => "VB",  :host => FactoryGirl.create(:host, :name => "HB"))
      vm3 =  FactoryGirl.create(:vm_vmware, :name => "VAA", :host => FactoryGirl.create(:host, :name => "HAA"))
      tag =  "/managed/environment/prod"
      group.entitlement = Entitlement.new
      group.entitlement.set_managed_filters([[tag]])
      group.save!

      # vm1's host.name starts with HA but isn't tagged
      vm2.tag_with(tag, :ns => "*")
      vm3.tag_with(tag, :ns => "*")

      allow(User).to receive_messages(:server_timezone => "UTC")

      report = MiqReport.new(:db => "Vm")

      filter = YAML.load '--- !ruby/object:MiqExpression
      exp:
        "starts with":
          field: Vm-host_name
          value: "HA"
      '

      results, attrs = report.paged_view_search(:only => %w(name host_name), :userid => user.userid, :filter => filter)
      expect(results.length).to eq 1
      expect(results.data.first["name"]).to eq "VAA"
      expect(results.data.first["host_name"]).to eq "HAA"
      expect(attrs[:user_filters]["managed"]).to eq [[tag]]
    end

    it "filtering on a virtual reflection" do
      vm1 = FactoryGirl.create(:vm_vmware, :name => "VA")
      vm2 = FactoryGirl.create(:vm_vmware, :name => "VB")
      rp1 = FactoryGirl.create(:resource_pool, :name => "RPA")
      rp2 = FactoryGirl.create(:resource_pool, :name => "RPB")
      rp1.add_child(vm1)
      rp2.add_child(vm2)

      report = MiqReport.new(:db => "Vm")
      filter = YAML.load '--- !ruby/object:MiqExpression
      exp:
        "starts with":
          field: Vm.parent_resource_pool-name
          value: "RPA"
      '

      results, _attrs = report.paged_view_search(:only => %w(name), :filter => filter)
      expect(results.length).to eq 1
      expect(results.data.first["name"]).to eq "VA"
    end

    it "virtual columns included in cols" do
      FactoryGirl.create(:vm_vmware, :host => FactoryGirl.create(:host, :name => "HA", :vmm_product => "ESX"))
      FactoryGirl.create(:vm_vmware, :host => FactoryGirl.create(:host, :name => "HB", :vmm_product => "ESX"))

      report = MiqReport.new(
        :name      => "VMs",
        :title     => "Virtual Machines",
        :db        => "Vm",
        :cols      => %w(name host_name v_host_vmm_product),
        :include   => {"host" => {"columns" => %w(name vmm_product)}},
        :col_order => %w(name host.name host.vmm_product),
        :headers   => ["Name", "Host", "Host VMM Product"],
        :order     => "Ascending",
        :sortby    => ["host_name"],
      )

      options = {
        :targets_hash => true,
        :userid       => "admin"
      }
      results, _attrs = report.paged_view_search(options)
      expect(results.length).to eq 2
      expect(results.data.collect { |rec| rec.data["host_name"] }).to eq(%w(HA HB))
      expect(results.data.collect { |rec| rec.data["v_host_vmm_product"] }).to eq(%w(ESX ESX))
    end
  end

  describe "#generate_table" do
    it "with has_many through" do
      ems      = FactoryGirl.create(:ems_vmware_with_authentication)
      user     = FactoryGirl.create(:user_with_group)
      group    = user.current_group
      template = FactoryGirl.create(:template_vmware, :ext_management_system => ems)
      vm       = FactoryGirl.create(:vm_vmware, :ext_management_system => ems)
      hardware = FactoryGirl.create(:hardware, :vm => vm)
      FactoryGirl.create(:disk, :hardware => hardware, :disk_type => "thin")

      options = {
        :vm_name        => vm.name,
        :vm_target_name => vm.name,
        :provision_type => "vmware",
        :src_vm_id      => [template.id, template.name]
      }

      provision = FactoryGirl.create(
        :miq_provision_vmware,
        :destination  => vm,
        :source       => template,
        :userid       => user.userid,
        :request_type => 'template',
        :state        => 'finished',
        :status       => 'Ok',
        :options      => options
      )

      template.miq_provisions_from_template << provision
      template.save

      expect(template.miq_provision_vms.count).to be > 0
      expect(template.miq_provision_vms.count(&:thin_provisioned)).to be > 0

      report = MiqReport.create(
        :name          => "VMs based on Disk Type",
        :title         => "VMs using thin provisioned disks",
        :rpt_group     => "Custom",
        :rpt_type      => "Custom",
        :db            => "MiqTemplate",
        :cols          => [],
        :include       => {"miq_provision_vms" => {"columns" => ["name"]}},
        :col_order     => ["miq_provision_vms.name"],
        :headers       => ["Name"],
        :template_type => "report",
        :miq_group_id  => group.id,
        :user_id       => user.userid,
        :conditions    => MiqExpression.new(
          {"FIND" => {"search" => {"=" => {"field" => "MiqTemplate.miq_provision_vms-thin_provisioned", "value" => "true"}}, "checkall" => {"=" => {"field" => "MiqTemplate.miq_provision_vms-thin_provisioned", "value" => "true"}}}},
          nil
        )
      )
      report.generate_table
      expect(report.table.data.collect { |rec| rec.data['miq_provision_vms.name'] }).to eq([vm.name])
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
    context "performance reports" do
      let(:report) do
        MiqReport.new(
          :title   => "vim_perf_daily.yaml",
          :db      => "VimPerformanceDaily",
          :cols    => %w(timestamp cpu_usagemhz_rate_average max_derived_cpu_available),
          :include => { "metric_rollup" => {
            "columns" => %w(cpu_usagemhz_rate_average_high_over_time_period
                            cpu_usagemhz_rate_average_low_over_time_period
                            derived_memory_used_high_over_time_period
                            derived_memory_used_low_over_time_period)}})
      end
      let(:ems) { FactoryGirl.create(:ems_vmware, :zone => @server.zone) }

      it "runs report" do
        report.generate_table(:userid => "admin")
      end
    end

    context "Tenant Quota Report" do
      include Spec::Support::QuotaHelper

      let!(:tenant_without_quotas) { FactoryGirl.create(:tenant, :name=>"tenant_without_quotas") }

      let(:skip_condition) do
        YAML.load '--- !ruby/object:MiqExpression
                       exp:
                         ">":
                           count: Tenant.tenant_quotas
                           value: 0'
      end

      let(:report) do
        include = {"tenant_quotas" => {"columns" => %w(name total used allocated available)}}
        cols = ["name", "tenant_quotas.name", "tenant_quotas.total", "tenant_quotas.used", "tenant_quotas.allocated",
                "tenant_quotas.available"]
        headers = ["Tenant Name", "Quota Name", "Total Quota", "Total Quota", "In Use", "Allocated", "Available"]

        FactoryGirl.create(:miq_report, :title => "Tenant Quotas", :order => 'Ascending', :rpt_group => "Custom",
                           :priority => 231, :rpt_type => 'Custom', :db => 'Tenant', :include => include, :cols => cols,
                           :col_order => cols, :template_type => "report", :headers => headers,
                           :conditions => skip_condition, :sortby => ["tenant_quotas.name"])
      end

      let(:user_admin) { FactoryGirl.create(:user, :role => "super_administrator") }

      def generate_table_cell(formatted_value)
        "<td style=\"text-align:right\">#{formatted_value}</td>"
      end

      def generate_html_row(is_even, tenant_name, formatted_values)
        row = []
        row << "<tr class='row#{is_even ? '0' : '1'}-nocursor'><td>#{tenant_name}</td>"

        [:name, :total, :used, :allocated, :available].each do |metric|
          row << generate_table_cell(formatted_values[metric])
        end

        row << "</tr>"
        row.join
      end

      before do
        setup_model

        # dummy child tenant
        FactoryGirl.create(:tenant, :parent => @tenant)

        # remove quotas that QuotaHelper already initialized
        @tenant.tenant_quotas = []

        @tenant.tenant_quotas.create :name => :cpu_allocated, :value => 2
        @tenant.tenant_quotas.create :name => :mem_allocated, :value => 4_294_967_296
        @tenant.tenant_quotas.create :name => :storage_allocated, :value => 4_294_967_296
        @tenant.tenant_quotas.create :name => :templates_allocated, :value => 4
        @tenant.tenant_quotas.create :name => :vms_allocated, :value => 4

        @expected_html_rows = []

        formatted_values = {:name => "Allocated Virtual CPUs", :total => "2 Count", :used => "0 Count",
                            :allocated => "0 Count", :available => "2 Count"}
        @expected_html_rows.push(generate_html_row(true, @tenant.name, formatted_values))

        formatted_values = {:name => "Allocated Memory in GB", :total => "4.0 GB", :used => "1.0 GB",
                            :allocated => "0.0 GB", :available => "3.0 GB"}
        @expected_html_rows.push(generate_html_row(false, @tenant.name, formatted_values))

        formatted_values = {:name => "Allocated Storage in GB", :total => "4.0 GB",
                            :used => "#{1_000_000.0 / 1.gigabyte} GB", :allocated => "0.0 GB",
                            :available => "#{(4.gigabytes - 1_000_000.0) / 1.gigabyte} GB"}
        @expected_html_rows.push(generate_html_row(true, @tenant.name, formatted_values))

        formatted_values = {:name => "Allocated Number of Templates", :total => "4 Count", :used => "1 Count",
                            :allocated => "0 Count", :available => "3 Count"}
        @expected_html_rows.push(generate_html_row(false, @tenant.name, formatted_values))

        formatted_values = {:name => "Allocated Number of Virtual Machines", :total => "4 Count", :used => "1 Count",
                            :allocated => "0 Count", :available => "3 Count"}
        @expected_html_rows.push(generate_html_row(true, @tenant.name, formatted_values))

        User.current_user = user_admin
      end

      it "returns expected html outputs with formatted values" do
        allow(User).to receive(:server_timezone).and_return("UTC")
        report.generate_table
        expect(report.build_html_rows).to match_array(@expected_html_rows)
      end

      it "returns only rows for tenant with any tenant_quotas" do
        allow(User).to receive(:server_timezone).and_return("UTC")
        report.generate_table
        # 6th row would be for tenant_without_quotas, but skipped now because of skip_condition, so we expecting 5
        expect(report.table.data.count).to eq(5)
      end
    end
  end

  describe ".ascending?" do
    it "handles nil" do
      report = MiqReport.new(:order => nil)
      expect(report).to be_ascending
    end

    it "handles ascending" do
      report = MiqReport.new(:order => "Ascending")
      expect(report).to be_ascending
    end

    it "handles descending" do
      report = MiqReport.new(:order => "Descending")
      expect(report).not_to be_ascending
    end
  end

  describe ".ascending=" do
    it "handles nil" do
      report = MiqReport.new
      report.ascending = true
      expect(report).to be_ascending
    end

    it "handles ascending" do
      report = MiqReport.new
      report.ascending = false
      expect(report).not_to be_ascending
    end
  end

  describe ".sort_col" do
    it "uses sort_by if available" do
      report = MiqReport.new(
        :db        => "Host",
        :cols      => %w(name hostname smart),
        :col_order => %w(name hostname smart),
        :sortby    => ["hostname"]
      )
      expect(report.sort_col).to eq(1)
    end

    it "falls back to first column" do
      report = MiqReport.new(
        :db        => "Host",
        :cols      => %w(name hostname smart),
        :col_order => %w(name hostname smart),
      )
      expect(report.sort_col).to eq(0)
    end
  end

  describe ".cols" do
    it "loads given value" do
      report = MiqReport.new(
        :cols      => %w(name)
      )
      expect(report.cols).to eq(%w(name))
    end

    it "falls back to col_order" do
      report = MiqReport.new(
        :col_order => %w(miq_custom_attributes.name miq_custom_attributes.value name)
      )
      expect(report.cols).to eq(%w(name))
    end

    it "allows manipulation" do
      report = MiqReport.new(
        :col_order => %w(miq_custom_attributes.name miq_custom_attributes.value name),
      )
      report.cols << "name2"
      expect(report.cols).to eq(%w(name name2))
    end
  end

  context "chargeback reports" do
    let(:hourly_rate) { 0.01 }
    let(:hourly_variable_tier_rate) { {:variable_rate => hourly_rate.to_s} }
    let(:detail_params) { {:chargeback_rate_detail_fixed_compute_cost => { :tiers => [hourly_variable_tier_rate] } } }
    let!(:chargeback_rate) do
      FactoryGirl.create(:chargeback_rate, :detail_params => detail_params)
    end
    let(:report_params) do
      {
        :rpt_group     => "Custom",
        :rpt_type      => "Custom",
        :include       => { :custom_attributes => {} },
        :group         => "y",
        :template_type => "report",
      }
    end

    before do
      MiqRegion.seed
      ChargebackRateDetailMeasure.seed
      ChargeableField.seed
      ChargebackRate.seed
      EvmSpecHelper.create_guid_miq_server_zone
    end

    context "chargeback based on container images" do
      let(:label_name) { "version" }
      let(:label_value) { "1.0.0" }
      let(:label) { FactoryGirl.build(:custom_attribute, :name => label_name, :value => label_value, :section => 'docker_labels') }
      let(:label_report_column) { "virtual_custom_attribute_#{label_name}" }
      let(:report) do
        MiqReport.new(
          report_params.merge(
            :db          => "ChargebackContainerImage",
            :cols        => ["start_date", "display_range", "project_name", "image_name", label_report_column],
            :col_order   => ["project_name", "image_name", "display_range", label_report_column],
            :headers     => ["Project Name", "Image Name", "Date Range", nil],
            :sortby      => ["project_name", "image_name", "start_date"],
            :db_options  => { :rpt_type => "ChargebackContainerImage",
                              :options  => { :interval            => "daily",
                                             :interval_size       => 28,
                                             :end_interval_offset => 1,
                                             :provider_id         => "all",
                                             :entity_id           => "all",
                                             :include_metrics     => true,
                                             :groupby             => "date",
                                             :groupby_tag         => nil }},
            :col_options => ChargebackContainerImage.report_col_options
          )
        )
      end

      it "runs a report with a custom attribute" do
        ems = FactoryGirl.create(:ems_openshift)
        image = FactoryGirl.create(:container_image, :ext_management_system => ems)
        image.docker_labels << label
        project_name = "my project"
        project = FactoryGirl.create(:container_project, :name => project_name, :ext_management_system => ems)
        group = FactoryGirl.create(:container_group, :ext_management_system => ems, :container_project => project)
        container = FactoryGirl.create(:kubernetes_container, :container_group => group, :container_image => image)
        container.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr,
                                                       :with_data,
                                                       :timestamp     => 1.day.ago,
                                                       :resource_id   => container.id,
                                                       :resource_name => container.name,
                                                       :parent_ems_id => ems.id,
                                                       :tag_names     => "")
        ChargebackRate.set_assignments(:compute, [{ :cb_rate => chargeback_rate, :label => [label, "container_image"] }])
        rpt = report.generate_table(:userid => "admin")
        expect(rpt.keys).to contain_exactly(project_name, :_total_)
        row = rpt[project_name][:row]
        expect(row[label_report_column]).to eq(label_value)
      end
    end

    context "chargeback based on container projects" do
      let(:label_name) { "version" }
      let(:label_value) { "1.0.0" }
      let(:label) { FactoryGirl.build(:custom_attribute, :name => label_name, :value => label_value, :section => 'labels') }
      let(:label_report_column) { "virtual_custom_attribute_#{label_name}" }
      let(:report) do
        MiqReport.new(
          report_params.merge(
            :db          => "ChargebackContainerProject",
            :cols        => ["start_date", "display_range", "project_name", label_report_column],
            :col_order   => ["project_name", "display_range", label_report_column],
            :headers     => ["Project Name", "Date Range", nil],
            :sortby      => ["project_name", "start_date"],
            :db_options  => {:rpt_type => "ChargebackContainerProject",
                             :options  => { :interval            => "daily",
                                            :interval_size       => 28,
                                            :end_interval_offset => 1,
                                            :provider_id         => "all",
                                            :entity_id           => "all",
                                            :include_metrics     => true,
                                            :groupby             => "date",
                                            :groupby_tag         => nil }},
            :col_options => ChargebackContainerProject.report_col_options
          )
        )
      end

      it "runs a report with a custom attribute" do
        ems = FactoryGirl.create(:ems_openshift)
        project_name = "my project"
        project = FactoryGirl.create(:container_project, :name => project_name, :ext_management_system => ems, :created_on => 2.days.ago)
        project.labels << label
        project.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr,
                                                     :with_data,
                                                     :timestamp     => 1.day.ago,
                                                     :resource_id   => project.id,
                                                     :resource_name => project.name,
                                                     :parent_ems_id => ems.id,
                                                     :tag_names     => "")
        ChargebackRate.set_assignments(:compute, [{ :cb_rate => chargeback_rate, :object => ems }])
        rpt = report.generate_table(:userid => "admin")
        row = rpt[project_name][:row]
        expect(row[label_report_column]).to eq(label_value)
      end
    end

    context "chargeback based on vms" do
      let(:label_name) { "version" }
      let(:label_value) { "1.0.0" }
      let(:label) { FactoryGirl.build(:custom_attribute, :name => label_name, :value => label_value, :section => 'labels') }
      let(:label_report_column) { "virtual_custom_attribute_#{label_name}" }
      let(:report) do
        MiqReport.new(
          report_params.merge(
            :db          => "ChargebackVm",
            :cols        => ["start_date", "display_range", "vm_name", label_report_column],
            :col_order   => ["vm_name", "display_range", label_report_column],
            :headers     => ["Vm Name", "Date Range", nil],
            :sortby      => ["vm_name", "start_date"],
            :db_options  => {:rpt_type => "ChargebackVm",
                             :options  => { :interval            => "daily",
                                            :interval_size       => 28,
                                            :end_interval_offset => 1,
                                            :provider_id         => "all",
                                            :entity_id           => "all",
                                            :include_metrics     => true,
                                            :groupby             => "date",
                                            :groupby_tag         => nil,
                                            :tag                 => '/managed/environment/prod'}},
            :col_options => ChargebackVm.report_col_options
          )
        )
      end

      it "runs a report with a custom attribute" do
        ems = FactoryGirl.create(:ems_vmware)

        cat = FactoryGirl.create(:classification, :description => "Environment", :name => "environment", :single_value => true, :show => true)
        c = FactoryGirl.create(:classification, :name => "prod", :description => "Production", :parent_id => cat.id)
        tag = Tag.find_by(:name => "/managed/environment/prod")

        temp = {:cb_rate => chargeback_rate, :tag => [c, "vm"]}
        ChargebackRate.set_assignments(:compute, [temp])
        vm_name = "test_vm"
        vm1 = FactoryGirl.create(:vm_vmware, :name => vm_name, :evm_owner => FactoryGirl.create(:user_admin), :ems_ref => "ems_ref",
                                  :created_on => 2.days.ago)
        vm1.tag_with(tag.name, :ns => '*')
        vm1.labels << label

        host1   = FactoryGirl.create(:host, :hardware => FactoryGirl.create(:hardware, :memory_mb => 8124, :cpu_total_cores => 1, :cpu_speed => 9576), :vms => [vm1])
        storage = FactoryGirl.create(:storage_target_vmware)
        host1.storages << storage

        ems_cluster = FactoryGirl.create(:ems_cluster, :ext_management_system => ems)
        ems_cluster.hosts << host1
        vm1.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr,
                                                 :with_data,
                                                 :timestamp             => 1.day.ago,
                                                 :resource_id           => vm1.id,
                                                 :resource_name         => vm1.name,
                                                 :tag_names             => "environment/prod",
                                                 :parent_host_id        => host1.id,
                                                 :parent_ems_cluster_id => ems_cluster.id,
                                                 :parent_ems_id         => ems.id,
                                                 :parent_storage_id     => storage.id)
        rpt = report.generate_table(:userid => "admin")
        row = rpt[vm_name][:row]
        expect(row[label_report_column]).to eq(label_value)
      end
    end
  end
end
