#
# REST API Querying capabilities
#   - Paging                - offset, limit
#   - Sorting               - sort_by=:attr, sort_oder = asc|desc
#   - Filtering             - filter[]=...
#   - Selecting Attributes  - attributes=:attr1,:attr2,...
#   - Querying by Tag       - by_tag=:tag_path  (i.e. /department/finance)
#   - Expanding Results     - expand=resources,:subcollection
#   - Resource actions
#
describe "Querying" do
  def create_vms_by_name(names)
    names.each.collect { |name| FactoryGirl.create(:vm_vmware, :name => name) }
  end

  let(:vm1) { FactoryGirl.create(:vm_vmware, :name => "vm1") }

  describe "Querying vms" do
    before { api_basic_authorize collection_action_identifier(:vms, :read, :get) }

    it "supports offset" do
      create_vms_by_name(%w(aa bb cc))

      run_get vms_url, :offset => 2

      expect_query_result(:vms, 1, 3)
    end

    it "supports limit" do
      create_vms_by_name(%w(aa bb cc))

      run_get vms_url, :limit => 2

      expect_query_result(:vms, 2, 3)
    end

    it "supports offset and limit" do
      create_vms_by_name(%w(aa bb cc))

      run_get vms_url, :offset => 1, :limit => 1

      expect_query_result(:vms, 1, 3)
    end

    it "supports paging via offset and limit" do
      create_vms_by_name %w(aa bb cc dd ee)

      run_get vms_url, :offset => 0, :limit => 2, :sort_by => "name", :expand => "resources"

      expect_query_result(:vms, 2, 5)
      expect_result_resources_to_match_hash([{"name" => "aa"}, {"name" => "bb"}])

      run_get vms_url, :offset => 2, :limit => 2, :sort_by => "name", :expand => "resources"

      expect_query_result(:vms, 2, 5)
      expect_result_resources_to_match_hash([{"name" => "cc"}, {"name" => "dd"}])

      run_get vms_url, :offset => 4, :limit => 2, :sort_by => "name", :expand => "resources"

      expect_query_result(:vms, 1, 5)
      expect_result_resources_to_match_hash([{"name" => "ee"}])
    end
  end

  describe "Sorting vms by attribute" do
    before { api_basic_authorize collection_action_identifier(:vms, :read, :get) }

    it "supports ascending order" do
      create_vms_by_name %w(cc aa bb)

      run_get vms_url, :sort_by => "name", :sort_order => "asc", :expand => "resources"

      expect_query_result(:vms, 3, 3)
      expect_result_resources_to_match_hash([{"name" => "aa"}, {"name" => "bb"}, {"name" => "cc"}])
    end

    it "supports decending order" do
      create_vms_by_name %w(cc aa bb)

      run_get vms_url, :sort_by => "name", :sort_order => "desc", :expand => "resources"

      expect_query_result(:vms, 3, 3)
      expect_result_resources_to_match_hash([{"name" => "cc"}, {"name" => "bb"}, {"name" => "aa"}])
    end

    it "supports case insensitive ordering" do
      create_vms_by_name %w(B c a)

      run_get vms_url, :sort_by => "name", :sort_order => "asc", :sort_options => "ignore_case", :expand => "resources"

      expect_query_result(:vms, 3, 3)
      expect_result_resources_to_match_hash([{"name" => "a"}, {"name" => "B"}, {"name" => "c"}])
    end

    it "supports sorting with physical attributes" do
      FactoryGirl.create(:vm_vmware, :vendor => "vmware", :name => "vmware_vm")
      FactoryGirl.create(:vm_redhat, :vendor => "redhat", :name => "redhat_vm")

      run_get vms_url, :sort_by => "vendor", :sort_order => "asc", :expand => "resources"

      expect_query_result(:vms, 2, 2)
      expect_result_resources_to_match_hash([{"name" => "redhat_vm"}, {"name" => "vmware_vm"}])
    end

    it 'supports sql friendly virtual attributes' do
      host_foo =  FactoryGirl.create(:host, :name => 'foo')
      host_bar =  FactoryGirl.create(:host, :name => 'bar')
      host_zap =  FactoryGirl.create(:host, :name => 'zap')
      FactoryGirl.create(:vm, :name => 'vm_foo', :host => host_foo)
      FactoryGirl.create(:vm, :name => 'vm_bar', :host => host_bar)
      FactoryGirl.create(:vm, :name => 'vm_zap', :host => host_zap)

      run_get vms_url, :sort_by => 'host_name', :sort_order => 'desc', :expand => 'resources'

      expect_query_result(:vms, 3, 3)
      expect_result_resources_to_match_hash([{'name' => 'vm_zap'}, {'name' => 'vm_foo'}, {'name' => 'vm_bar'}])
    end

    it 'does not support non sql friendly virtual attributes' do
      FactoryGirl.create(:vm)

      run_get vms_url, :sort_by => 'aggressive_recommended_mem', :sort_order => 'asc'

      expected = {
        'error' => a_hash_including(
          'message' => 'Vm cannot be sorted by aggressive_recommended_mem'
        )
      }
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to include(expected)
    end
  end

  describe "Filtering vms" do
    before { api_basic_authorize collection_action_identifier(:vms, :read, :get) }

    it "supports attribute equality test using double quotes" do
      _vm1, vm2 = create_vms_by_name(%w(aa bb))

      run_get vms_url, :expand => "resources", :filter => ['name="bb"']

      expect_query_result(:vms, 1, 2)
      expect_result_resources_to_match_hash([{"name" => vm2.name, "guid" => vm2.guid}])
    end

    it "supports attribute equality test using single quotes" do
      vm1, _vm2 = create_vms_by_name(%w(aa bb))

      run_get vms_url, :expand => "resources", :filter => ["name='aa'"]

      expect_query_result(:vms, 1, 2)
      expect_result_resources_to_match_hash([{"name" => vm1.name, "guid" => vm1.guid}])
    end

    it "supports attribute pattern matching via %" do
      vm1, _vm2, vm3 = create_vms_by_name(%w(aa_B2 bb aa_A1))

      run_get vms_url, :expand => "resources", :filter => ["name='aa%'"], :sort_by => "name"

      expect_query_result(:vms, 2, 3)
      expect_result_resources_to_match_hash([{"name" => vm3.name, "guid" => vm3.guid},
                                             {"name" => vm1.name, "guid" => vm1.guid}])
    end

    it "supports attribute pattern matching via *" do
      vm1, _vm2, vm3 = create_vms_by_name(%w(aa_B2 bb aa_A1))

      run_get vms_url, :expand => "resources", :filter => ["name='aa*'"], :sort_by => "name"

      expect_query_result(:vms, 2, 3)
      expect_result_resources_to_match_hash([{"name" => vm3.name, "guid" => vm3.guid},
                                             {"name" => vm1.name, "guid" => vm1.guid}])
    end

    it "supports inequality test via !=" do
      vm1, _vm2, vm3 = create_vms_by_name(%w(aa bb cc))

      run_get vms_url, :expand => "resources", :filter => ["name!='b%'"], :sort_by => "name"

      expect_query_result(:vms, 2, 3)
      expect_result_resources_to_match_hash([{"name" => vm1.name, "guid" => vm1.guid},
                                             {"name" => vm3.name, "guid" => vm3.guid}])
    end

    it "supports NULL/nil equality test via =" do
      vm1, vm2 = create_vms_by_name(%w(aa bb))
      vm2.update_attributes!(:retired => true)

      run_get vms_url, :expand => "resources", :filter => ["retired=NULL"]

      expect_query_result(:vms, 1, 2)
      expect_result_resources_to_match_hash([{"name" => vm1.name, "guid" => vm1.guid}])
    end

    it "supports NULL/nil inequality test via !=" do
      _vm1, vm2 = create_vms_by_name(%w(aa bb))
      vm2.update_attributes!(:retired => true)

      run_get vms_url, :expand => "resources", :filter => ["retired!=nil"]

      expect_query_result(:vms, 1, 2)
      expect_result_resources_to_match_hash([{"name" => vm2.name, "guid" => vm2.guid}])
    end

    it "supports numerical less than comparison via <" do
      vm1, vm2, vm3 = create_vms_by_name(%w(aa bb cc))

      run_get vms_url, :expand => "resources", :filter => ["id < #{vm3.id}"], :sort_by => "name"

      expect_query_result(:vms, 2, 3)
      expect_result_resources_to_match_hash([{"name" => vm1.name, "guid" => vm1.guid},
                                             {"name" => vm2.name, "guid" => vm2.guid}])
    end

    it "supports numerical less than or equal comparison via <=" do
      vm1, vm2, _vm3 = create_vms_by_name(%w(aa bb cc))

      run_get vms_url, :expand => "resources", :filter => ["id <= #{vm2.id}"], :sort_by => "name"

      expect_query_result(:vms, 2, 3)
      expect_result_resources_to_match_hash([{"name" => vm1.name, "guid" => vm1.guid},
                                             {"name" => vm2.name, "guid" => vm2.guid}])
    end

    it "support greater than numerical comparison via >" do
      vm1, vm2 = create_vms_by_name(%w(aa bb))

      run_get vms_url, :expand => "resources", :filter => ["id > #{vm1.id}"], :sort_by => "name"

      expect_query_result(:vms, 1, 2)
      expect_result_resources_to_match_hash([{"name" => vm2.name, "guid" => vm2.guid}])
    end

    it "supports greater or equal than numerical comparison via >=" do
      _vm1, vm2, vm3 = create_vms_by_name(%w(aa bb cc))

      run_get vms_url, :expand => "resources", :filter => ["id >= #{vm2.id}"], :sort_by => "name"

      expect_query_result(:vms, 2, 3)
      expect_result_resources_to_match_hash([{"name" => vm2.name, "guid" => vm2.guid},
                                             {"name" => vm3.name, "guid" => vm3.guid}])
    end

    it "supports compound logical OR comparisons" do
      vm1, vm2, vm3 = create_vms_by_name(%w(aa bb cc))

      run_get vms_url, :expand  => "resources",
                       :filter  => ["id = #{vm1.id}", "or id > #{vm2.id}"],
                       :sort_by => "name"

      expect_query_result(:vms, 2, 3)
      expect_result_resources_to_match_hash([{"name" => vm1.name, "guid" => vm1.guid},
                                             {"name" => vm3.name, "guid" => vm3.guid}])
    end

    it "supports multiple logical AND comparisons" do
      vm1, _vm2 = create_vms_by_name(%w(aa bb))

      run_get vms_url, :expand => "resources",
                       :filter => ["id = #{vm1.id}", "name = #{vm1.name}"]

      expect_query_result(:vms, 1, 2)
      expect_result_resources_to_match_hash([{"name" => vm1.name, "guid" => vm1.guid}])
    end

    it "supports multiple comparisons with both AND and OR" do
      vm1, vm2, vm3 = create_vms_by_name(%w(aa bb cc))

      run_get vms_url, :expand  => "resources",
                       :filter  => ["id = #{vm1.id}", "name = #{vm1.name}", "or id > #{vm2.id}"],
                       :sort_by => "name"

      expect_query_result(:vms, 2, 3)
      expect_result_resources_to_match_hash([{"name" => vm1.name, "guid" => vm1.guid},
                                             {"name" => vm3.name, "guid" => vm3.guid}])
    end

    it "supports filtering by attributes of associations" do
      host1 = FactoryGirl.create(:host, :name => "foo")
      host2 = FactoryGirl.create(:host, :name => "bar")
      vm1 = FactoryGirl.create(:vm_vmware, :name => "baz", :host => host1)
      _vm2 = FactoryGirl.create(:vm_vmware, :name => "qux", :host => host2)

      run_get vms_url, :expand => "resources",
                       :filter => ["host.name='foo'"]

      expect_query_result(:vms, 1, 2)
      expect_result_resources_to_match_hash([{"name" => vm1.name, "guid" => vm1.guid}])
    end

    it "does not support filtering by attributes of associations' associations" do
      run_get vms_url, :expand => "resources", :filter => ["host.hardware.memory_mb>1024"]

      expect_bad_request(/Filtering of attributes with more than one association away is not supported/)
    end

    it "supports filtering by virtual string attributes" do
      host_a = FactoryGirl.create(:host, :name => "aa")
      host_b = FactoryGirl.create(:host, :name => "bb")
      vm_a = FactoryGirl.create(:vm, :host => host_a)
      _vm_b = FactoryGirl.create(:vm, :host => host_b)

      run_get(vms_url, :filter => ["host_name='aa'"], :expand => "resources")

      expect_query_result(:vms, 1, 2)
      expect_result_resources_to_match_hash([{"name" => vm_a.name, "guid" => vm_a.guid}])
    end

    it "supports flexible filtering by virtual string attributes" do
      host_a = FactoryGirl.create(:host, :name => "ab")
      host_b = FactoryGirl.create(:host, :name => "cd")
      vm_a = FactoryGirl.create(:vm, :host => host_a)
      _vm_b = FactoryGirl.create(:vm, :host => host_b)

      run_get(vms_url, :filter => ["host_name='a%'"], :expand => "resources")

      expect_query_result(:vms, 1, 2)
      expect_result_resources_to_match_hash([{"name" => vm_a.name, "guid" => vm_a.guid}])
    end

    it "supports filtering by virtual boolean attributes" do
      ems = FactoryGirl.create(:ext_management_system)
      storage = FactoryGirl.create(:storage)
      host = FactoryGirl.create(:host, :storages => [storage])
      _vm = FactoryGirl.create(:vm, :host => host, :ext_management_system => ems)
      archived_vm = FactoryGirl.create(:vm)

      run_get(vms_url, :filter => ["archived=true"], :expand => "resources")

      expect_query_result(:vms, 1, 2)
      expect_result_resources_to_match_hash([{"name" => archived_vm.name, "guid" => archived_vm.guid}])
    end

    it "supports filtering by comparison of virtual integer attributes" do
      hardware_1 = FactoryGirl.create(:hardware, :cpu_sockets => 4)
      hardware_2 = FactoryGirl.create(:hardware, :cpu_sockets => 8)
      _vm_1 = FactoryGirl.create(:vm, :hardware => hardware_1)
      vm_2 = FactoryGirl.create(:vm, :hardware => hardware_2)

      run_get(vms_url, :filter => ["num_cpu > 4"], :expand => "resources")

      expect_query_result(:vms, 1, 2)
      expect_result_resources_to_match_hash([{"name" => vm_2.name, "guid" => vm_2.guid}])
    end

    it "supports = with dates mixed with virtual attributes" do
      _vm_1 = FactoryGirl.create(:vm, :retires_on => "2016-01-01", :vendor => "vmware")
      vm_2 = FactoryGirl.create(:vm, :retires_on => "2016-01-02", :vendor => "vmware")
      _vm_3 = FactoryGirl.create(:vm, :retires_on => "2016-01-02", :vendor => "openstack")

      run_get(vms_url, :filter => ["retires_on = 2016-01-02", "vendor_display = VMware"])

      expected = {"resources" => [{"href" => a_string_matching(vms_url(vm_2.id))}]}
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it "supports > with dates mixed with virtual attributes" do
      _vm_1 = FactoryGirl.create(:vm, :retires_on => "2016-01-01", :vendor => "vmware")
      vm_2 = FactoryGirl.create(:vm, :retires_on => "2016-01-02", :vendor => "vmware")
      _vm_3 = FactoryGirl.create(:vm, :retires_on => "2016-01-03", :vendor => "openstack")

      run_get(vms_url, :filter => ["retires_on > 2016-01-01", "vendor_display = VMware"])

      expected = {"resources" => [{"href" => a_string_matching(vms_url(vm_2.id))}]}
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it "supports > with datetimes mixed with virtual attributes" do
      _vm_1 = FactoryGirl.create(:vm, :last_scan_on => "2016-01-01T07:59:59Z", :vendor => "vmware")
      vm_2 = FactoryGirl.create(:vm, :last_scan_on => "2016-01-01T08:00:00Z", :vendor => "vmware")
      _vm_3 = FactoryGirl.create(:vm, :last_scan_on => "2016-01-01T08:00:00Z", :vendor => "openstack")

      run_get(vms_url, :filter => ["last_scan_on > 2016-01-01T07:59:59Z", "vendor_display = VMware"])

      expected = {"resources" => [{"href" => a_string_matching(vms_url(vm_2.id))}]}
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it "supports < with dates mixed with virtual attributes" do
      _vm_1 = FactoryGirl.create(:vm, :retires_on => "2016-01-01", :vendor => "openstack")
      vm_2 = FactoryGirl.create(:vm, :retires_on => "2016-01-02", :vendor => "vmware")
      _vm_3 = FactoryGirl.create(:vm, :retires_on => "2016-01-03", :vendor => "vmware")

      run_get(vms_url, :filter => ["retires_on < 2016-01-03", "vendor_display = VMware"])

      expected = {"resources" => [{"href" => a_string_matching(vms_url(vm_2.id))}]}
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it "supports < with datetimes mixed with virtual attributes" do
      _vm_1 = FactoryGirl.create(:vm, :last_scan_on => "2016-01-01T07:59:59Z", :vendor => "openstack")
      vm_2 = FactoryGirl.create(:vm, :last_scan_on => "2016-01-01T07:59:59Z", :vendor => "vmware")
      _vm_3 = FactoryGirl.create(:vm, :last_scan_on => "2016-01-01T08:00:00Z", :vendor => "vmware")

      run_get(vms_url, :filter => ["last_scan_on < 2016-01-01T08:00:00Z", "vendor_display = VMware"])

      expected = {"resources" => [{"href" => a_string_matching(vms_url(vm_2.id))}]}
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it "does not support filtering with <= with datetimes" do
      run_get(vms_url, :filter => ["retires_on <= 2016-01-03"])

      expect(response.parsed_body).to include_error_with_message("Unsupported operator for datetime: <=")
      expect(response).to have_http_status(:bad_request)
    end

    it "does not support filtering with >= with datetimes" do
      run_get(vms_url, :filter => ["retires_on >= 2016-01-03"])

      expect(response.parsed_body).to include_error_with_message("Unsupported operator for datetime: >=")
      expect(response).to have_http_status(:bad_request)
    end

    it "does not support filtering with != with datetimes" do
      run_get(vms_url, :filter => ["retires_on != 2016-01-03"])

      expect(response.parsed_body).to include_error_with_message("Unsupported operator for datetime: !=")
      expect(response).to have_http_status(:bad_request)
    end

    it "will handle poorly formed datetimes in the filter" do
      run_get(vms_url, :filter => ["retires_on > foobar"])

      expect(response.parsed_body).to include_error_with_message("Bad format for datetime: foobar")
      expect(response).to have_http_status(:bad_request)
    end

    it "does not support filtering vms as a subcollection" do
      service = FactoryGirl.create(:service)
      service << FactoryGirl.create(:vm_vmware, :name => "foo")
      service << FactoryGirl.create(:vm_vmware, :name => "bar")

      run_get("#{services_url(service.id)}/vms", :filter => ["name=foo"])

      expect(response.parsed_body).to include_error_with_message("Filtering is not supported on vms subcollection")
      expect(response).to have_http_status(:bad_request)
    end

    it "can do fuzzy matching on strings with forward slashes" do
      tag_1 = FactoryGirl.create(:tag, :name => "/managed/foo")
      _tag_2 = FactoryGirl.create(:tag, :name => "/managed/bar")
      api_basic_authorize collection_action_identifier(:tags, :read, :get)

      run_get(tags_url, :filter => ["name='*/foo'"])

      expected = {
        "count"     => 2,
        "subcount"  => 1,
        "resources" => [{"href" => a_string_matching(tags_url(tag_1.id))}]
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "Querying vm attributes" do
    it "supports requests specific attributes" do
      api_basic_authorize collection_action_identifier(:vms, :read, :get)
      vm = create_vms_by_name(%w(aa)).first

      run_get vms_url, :expand => "resources", :attributes => "name,vendor"

      expected = {
        "name"      => "vms",
        "count"     => 1,
        "subcount"  => 1,
        "resources" => [
          {
            "id"     => vm.id,
            "href"   => a_string_matching(vms_url(vm.id)),
            "name"   => "aa",
            "vendor" => anything
          }
        ]
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it "skips requests of invalid attributes" do
      api_basic_authorize action_identifier(:vms, :read, :resource_actions, :get)

      run_get vms_url(vm1.id), :attributes => "bogus"

      expect(response).to have_http_status(:ok)
      expect_result_to_have_keys(%w(id href name vendor))
    end
  end

  describe "Querying vms by tag" do
    it "is supported" do
      api_basic_authorize collection_action_identifier(:vms, :read, :get)
      vm1, _vm2, vm3 = create_vms_by_name(%w(aa bb cc))

      dept = FactoryGirl.create(:classification_department)
      FactoryGirl.create(:classification_tag, :name => "finance", :description => "Finance", :parent => dept)
      Classification.classify(vm1, "department", "finance")
      Classification.classify(vm3, "department", "finance")

      run_get vms_url, :expand => "resources", :by_tag => "/department/finance"

      expect_query_result(:vms, 2, 3)
      expect_result_resources_to_include_data("resources", "name" => [vm1.name, vm3.name])
    end
  end

  describe "Querying vms" do
    before { api_basic_authorize collection_action_identifier(:vms, :read, :get) }

    it "and sorted by name succeeeds with unreferenced class" do
      run_get vms_url, :sort_by => "name", :expand => "resources"

      expect_query_result(:vms, 0, 0)
    end

    it "by invalid attribute" do
      run_get vms_url, :sort_by => "bad_attribute", :expand => "resources"

      expect_bad_request("bad_attribute is not a valid attribute")
    end

    it "is supported without expanding resources" do
      create_vms_by_name(%w(aa bb))

      run_get vms_url

      expected = {
        "name"      => "vms",
        "count"     => 2,
        "subcount"  => 2,
        "resources" => Array.new(2) { {"href" => anything} }
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it "supports expanding resources" do
      create_vms_by_name(%w(aa bb))

      run_get vms_url, :expand => "resources"

      expect_query_result(:vms, 2, 2)
      expect_result_resources_to_include_keys("resources", %w(id href guid name vendor))
    end

    it "supports expanding resources and subcollections" do
      vm1 = create_vms_by_name(%w(aa)).first
      FactoryGirl.create(:guest_application, :vm_or_template_id => vm1.id, :name => "LibreOffice")

      run_get vms_url, :expand => "resources,software"

      expect_query_result(:vms, 1, 1)
      expect_result_resources_to_include_keys("resources", %w(id href guid name vendor software))
    end

    it "supports suppressing resources" do
      FactoryGirl.create(:vm)

      run_get(vms_url, :hide => "resources")

      expect(response.parsed_body).not_to include("resources")
      expect(response).to have_http_status(:ok)
    end
  end

  describe "Querying resources" do
    it "does not return actions if not entitled" do
      api_basic_authorize action_identifier(:vms, :read, :resource_actions, :get)

      run_get vms_url(vm1.id)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to_not have_key("actions")
    end

    it "returns actions if authorized" do
      api_basic_authorize action_identifier(:vms, :edit), action_identifier(:vms, :read, :resource_actions, :get)

      run_get vms_url(vm1.id)

      expect(response).to have_http_status(:ok)
      expect_result_to_have_keys(%w(id href name vendor actions))
    end

    it "returns correct actions if authorized as such" do
      api_basic_authorize action_identifier(:vms, :suspend), action_identifier(:vms, :read, :resource_actions, :get)

      run_get vms_url(vm1.id)

      expect(response).to have_http_status(:ok)
      expect_result_to_have_keys(%w(id href name vendor actions))
      actions = response.parsed_body["actions"]
      expect(actions.size).to eq(1)
      expect(actions.first["name"]).to eq("suspend")
    end

    it "returns multiple actions if authorized as such" do
      api_basic_authorize(action_identifier(:vms, :start),
                          action_identifier(:vms, :stop),
                          action_identifier(:vms, :read, :resource_actions, :get))

      run_get vms_url(vm1.id)

      expect(response).to have_http_status(:ok)
      expect_result_to_have_keys(%w(id href name vendor actions))
      expect(response.parsed_body["actions"].collect { |a| a["name"] }).to match_array(%w(start stop))
    end

    it "returns actions if asked for with physical attributes" do
      api_basic_authorize action_identifier(:vms, :start), action_identifier(:vms, :read, :resource_actions, :get)

      run_get vms_url(vm1.id), :attributes => "name,vendor,actions"

      expect(response).to have_http_status(:ok)
      expect_result_to_have_only_keys(%w(id href name vendor actions))
    end

    it "does not return actions if asking for a physical attribute" do
      api_basic_authorize action_identifier(:vms, :start), action_identifier(:vms, :read, :resource_actions, :get)

      run_get vms_url(vm1.id), :attributes => "name"

      expect(response).to have_http_status(:ok)
      expect_result_to_have_only_keys(%w(id href name))
    end

    it "does return actions if asking for virtual attributes" do
      api_basic_authorize action_identifier(:vms, :start), action_identifier(:vms, :read, :resource_actions, :get)

      run_get vms_url(vm1.id), :attributes => "disconnected"

      expect(response).to have_http_status(:ok)
      expect_result_to_have_keys(%w(id href name vendor disconnected actions))
    end

    it "does not return actions if asking for physical and virtual attributes" do
      api_basic_authorize action_identifier(:vms, :start), action_identifier(:vms, :read, :resource_actions, :get)

      run_get vms_url(vm1.id), :attributes => "name,disconnected"

      expect(response).to have_http_status(:ok)
      expect_result_to_have_only_keys(%w(id href name disconnected))
    end
  end

  describe 'OPTIONS /api/vms' do
    it 'returns the options information' do
      api_basic_authorize
      expected = {
        'attributes'         => (Vm.attribute_names - Vm.virtual_attribute_names).sort.as_json,
        'virtual_attributes' => Vm.virtual_attribute_names.sort.as_json,
        'relationships'      => (Vm.reflections.keys | Vm.virtual_reflections.keys.collect(&:to_s)).sort,
        'data'               => {}
      }
      run_options(vms_url)
      expect(response.parsed_body).to eq(expected)
      expect(response.headers['Access-Control-Allow-Methods']).to include('OPTIONS')
    end
  end
end
