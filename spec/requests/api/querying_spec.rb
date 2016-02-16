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
describe ApiController do
  include_context "api request specs"

  def create_vms_by_name(names)
    names.each.collect { |name| FactoryGirl.create(:vm_vmware, :name => name) }
  end

  let(:vm1) { FactoryGirl.create(:vm_vmware, :name => "vm1") }

  describe "Querying vms" do
    before { api_basic_authorize }

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
    before { api_basic_authorize }

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
  end

  describe "Filtering vms" do
    before { api_basic_authorize }

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
  end

  describe "Querying vm attributes" do
    it "supports requests specific attributes" do
      api_basic_authorize
      vm = create_vms_by_name(%w(aa)).first

      run_get vms_url, :expand => "resources", :attributes => "name,vendor"

      expect_query_result(:vms, 1, 1)
      expect_result_resources_to_have_only_keys("resources", %w(id href name vendor))
      expect_result_resources_to_match_hash([{"name" => "aa", "id" => vm.id, "href" => vms_url(vm.id)}])
    end

    it "skips requests of invalid attributes" do
      api_basic_authorize

      run_get vms_url(vm1.id), :attributes => "bogus"

      expect_request_success
      expect_result_to_have_keys(%w(id href name vendor))
    end
  end

  describe "Querying vms by tag" do
    it "is supported" do
      api_basic_authorize
      vm1, _vm2, vm3 = create_vms_by_name(%w(aa bb cc))

      dept = FactoryGirl.create(:classification_department)
      FactoryGirl.create(:classification_tag, :name => "finance", :description => "Finance", :parent => dept)
      Classification.classify(vm1, "department", "finance")
      Classification.classify(vm3, "department", "finance")

      run_get vms_url, :expand  => "resources", :by_tag => "/department/finance"

      expect_query_result(:vms, 2, 3)
      expect_result_resources_to_include_data("resources", "name" => [vm1.name, vm3.name])
    end
  end

  describe "Querying vms" do
    before { api_basic_authorize }

    it "is supported without expanding resources" do
      create_vms_by_name(%w(aa bb))

      run_get vms_url

      expect_query_result(:vms, 2, 2)
      expect_result_resources_to_have_only_keys("resources", %w(href))
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
  end

  describe "Querying resources" do
    it "does not return actions if not entitled" do
      api_basic_authorize

      run_get vms_url(vm1.id)

      expect_request_success
      expect(@result).to_not have_key("actions")
    end

    it "returns actions if authorized" do
      api_basic_authorize action_identifier(:vms, :edit)

      run_get vms_url(vm1.id)

      expect_request_success
      expect_result_to_have_keys(%w(id href name vendor actions))
    end

    it "returns correct actions if authorized as such" do
      api_basic_authorize action_identifier(:vms, :suspend)

      run_get vms_url(vm1.id)

      expect_request_success
      expect_result_to_have_keys(%w(id href name vendor actions))
      actions = @result["actions"]
      expect(actions.size).to eq(1)
      expect(actions.first["name"]).to eq("suspend")
    end

    it "returns multiple actions if authorized as such" do
      api_basic_authorize
      update_user_role(@role, action_identifier(:vms, :start), action_identifier(:vms, :stop))

      run_get vms_url(vm1.id)

      expect_request_success
      expect_result_to_have_keys(%w(id href name vendor actions))
      expect(@result["actions"].collect { |a| a["name"] }).to match_array(%w(start stop))
    end

    it "returns actions if asked for with physical attributes" do
      api_basic_authorize action_identifier(:vms, :start)

      run_get vms_url(vm1.id), :attributes => "name,vendor,actions"

      expect_request_success
      expect_result_to_have_only_keys(%w(id href name vendor actions))
    end

    it "does not return actions if asking for a physical attribute" do
      api_basic_authorize action_identifier(:vms, :start)

      run_get vms_url(vm1.id), :attributes => "name"

      expect_request_success
      expect_result_to_have_only_keys(%w(id href name))
    end

    it "does return actions if asking for virtual attributes" do
      api_basic_authorize action_identifier(:vms, :start)

      run_get vms_url(vm1.id), :attributes => "disconnected"

      expect_request_success
      expect_result_to_have_keys(%w(id href name vendor disconnected actions))
    end

    it "does not return actions if asking for physical and virtual attributes" do
      api_basic_authorize action_identifier(:vms, :start)

      run_get vms_url(vm1.id), :attributes => "name,disconnected"

      expect_request_success
      expect_result_to_have_only_keys(%w(id href name disconnected))
    end
  end
end
