#
# REST API Querying capabilities
#   - Paging                - offset, limit
#   - Sorting               - sort_by=:attr, sort_oder = asc|desc
#   - Filtering             - filter[]=...
#   - Selecting Attributes  - attributes=:attr1,:attr2,...
#   - Querying by Tag       - by_tag=:tag_path  (i.e. /department/finance)
#   - Expanding Results     - expand=resources,:subcollection
#
require 'spec_helper'

describe ApiController do
  include Rack::Test::Methods

  before(:each) do
    init_api_spec_env
  end

  def app
    Vmdb::Application
  end

  def create_vms(count)
    count.times.collect { FactoryGirl.create(:vm_vmware) }
  end

  def create_vms_by_name(names)
    names.each.collect { |name| FactoryGirl.create(:vm_vmware, :name => name) }
  end

  context "Query - paging vms" do
    it "to support offset" do
      api_basic_authorize
      create_vms(3)

      run_get vms_url, :offset => 2

      expect_query_result(:vms, 1, 3)
    end

    it "to support limit" do
      api_basic_authorize
      create_vms(3)

      run_get vms_url, :limit => 2

      expect_query_result(:vms, 2, 3)
    end

    it "to support offset and limit" do
      api_basic_authorize
      create_vms(3)

      run_get vms_url, :offset => 1, :limit => 1

      expect_query_result(:vms, 1, 3)
    end

    it "to support paging via offset and limit" do
      api_basic_authorize
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

  context "Query - sorting vms" do
    it "to support sorting by name in ascending order" do
      api_basic_authorize
      create_vms_by_name %w(cc aa bb)

      run_get vms_url, :sort_by => "name", :sort_order => "asc", :expand => "resources"

      expect_query_result(:vms, 3, 3)
      expect_result_resources_to_match_hash([{"name" => "aa"}, {"name" => "bb"}, {"name" => "cc"}])
    end

    it "to support sorting by name in decending order" do
      api_basic_authorize
      create_vms_by_name %w(cc aa bb)

      run_get vms_url, :sort_by => "name", :sort_order => "desc", :expand => "resources"

      expect_query_result(:vms, 3, 3)
      expect_result_resources_to_match_hash([{"name" => "cc"}, {"name" => "bb"}, {"name" => "aa"}])
    end
  end

  context "Query - filtering vms" do
    it "by exact name using double quotes" do
      api_basic_authorize
      _vm1, vm2 = create_vms_by_name(%w(aa bb))

      run_get vms_url, :expand => "resources", :filter => ['name="bb"']

      expect_query_result(:vms, 1, 2)
      expect_result_resources_to_match_hash([{"name" => vm2.name, "guid" => vm2.guid}])
    end

    it "by exact name using single quotes" do
      api_basic_authorize
      vm1, _vm2 = create_vms_by_name(%w(aa bb))

      run_get vms_url, :expand => "resources", :filter => ["name='aa'"]

      expect_query_result(:vms, 1, 2)
      expect_result_resources_to_match_hash([{"name" => vm1.name, "guid" => vm1.guid}])
    end

    it "by name match" do
      api_basic_authorize
      vm1, _vm2, vm3 = create_vms_by_name(%w(aa_B2 bb aa_A1))

      run_get vms_url, :expand => "resources", :filter => ["name='aa%'"], :sort_by => "name"

      expect_query_result(:vms, 2, 3)
      expect_result_resources_to_match_hash([{"name" => vm3.name, "guid" => vm3.guid},
                                             {"name" => vm1.name, "guid" => vm1.guid}])
    end

    it "by name inequality match via !=" do
      api_basic_authorize
      vm1, _vm2, vm3 = create_vms_by_name(%w(aa bb cc))

      run_get vms_url, :expand => "resources", :filter => ["name!='b%'"], :sort_by => "name"

      expect_query_result(:vms, 2, 3)
      expect_result_resources_to_match_hash([{"name" => vm1.name, "guid" => vm1.guid},
                                             {"name" => vm3.name, "guid" => vm3.guid}])
    end

    it "by id comparison using <" do
      api_basic_authorize
      vm1, vm2, vm3 = create_vms_by_name(%w(aa bb cc))

      run_get vms_url, :expand => "resources", :filter => ["id < #{vm3.id}"], :sort_by => "name"

      expect_query_result(:vms, 2, 3)
      expect_result_resources_to_match_hash([{"name" => vm1.name, "guid" => vm1.guid},
                                             {"name" => vm2.name, "guid" => vm2.guid}])
    end

    it "by id comparison using <=" do
      api_basic_authorize
      vm1, vm2, _vm3 = create_vms_by_name(%w(aa bb cc))

      run_get vms_url, :expand => "resources", :filter => ["id <= #{vm2.id}"], :sort_by => "name"

      expect_query_result(:vms, 2, 3)
      expect_result_resources_to_match_hash([{"name" => vm1.name, "guid" => vm1.guid},
                                             {"name" => vm2.name, "guid" => vm2.guid}])
    end

    it "by id comparison using >" do
      api_basic_authorize
      vm1, vm2 = create_vms_by_name(%w(aa bb))

      run_get vms_url, :expand => "resources", :filter => ["id > #{vm1.id}"], :sort_by => "name"

      expect_query_result(:vms, 1, 2)
      expect_result_resources_to_match_hash([{"name" => vm2.name, "guid" => vm2.guid}])
    end

    it "by id comparison using >=" do
      api_basic_authorize
      _vm1, vm2, vm3 = create_vms_by_name(%w(aa bb cc))

      run_get vms_url, :expand => "resources", :filter => ["id >= #{vm2.id}"], :sort_by => "name"

      expect_query_result(:vms, 2, 3)
      expect_result_resources_to_match_hash([{"name" => vm2.name, "guid" => vm2.guid},
                                             {"name" => vm3.name, "guid" => vm3.guid}])
    end

    it "by compound id comparison using = and > (OR)" do
      api_basic_authorize
      vm1, vm2, vm3 = create_vms_by_name(%w(aa bb cc))

      run_get vms_url, :expand  => "resources",
                       :filter  => ["id = #{vm1.id}", "or id > #{vm2.id}"],
                       :sort_by => "name"

      expect_query_result(:vms, 2, 3)
      expect_result_resources_to_match_hash([{"name" => vm1.name, "guid" => vm1.guid},
                                             {"name" => vm3.name, "guid" => vm3.guid}])
    end

    it "by multilple comparisons (AND)" do
      api_basic_authorize
      vm1, _vm2 = create_vms_by_name(%w(aa bb))

      run_get vms_url, :expand => "resources",
                       :filter => ["id = #{vm1.id}", "name = #{vm1.name}"]

      expect_query_result(:vms, 1, 2)
      expect_result_resources_to_match_hash([{"name" => vm1.name, "guid" => vm1.guid}])
    end

    it "by multilple comparisons (AND and OR)" do
      api_basic_authorize
      vm1, vm2, vm3 = create_vms_by_name(%w(aa bb cc))

      run_get vms_url, :expand  => "resources",
                       :filter  => ["id = #{vm1.id}", "name = #{vm1.name}", "or id > #{vm2.id}"],
                       :sort_by => "name"

      expect_query_result(:vms, 2, 3)
      expect_result_resources_to_match_hash([{"name" => vm1.name, "guid" => vm1.guid},
                                             {"name" => vm3.name, "guid" => vm3.guid}])
    end
  end

  context "Query - selecting attributes of a vm" do
    it "to request specific attributes" do
      api_basic_authorize
      vm = create_vms_by_name(%w(aa)).first

      run_get vms_url, :expand => "resources", :attributes => "name,vendor"

      expect_query_result(:vms, 1, 1)
      expect_result_resources_to_have_only_keys("resources", %w(id href name vendor))
      expect_result_resources_to_match_hash([{"name" => "aa", "id" => vm.id, "href" => vms_url(vm.id)}])
    end

    it "to request an invalid attribute" do
      api_basic_authorize
      vm = create_vms_by_name(%w(aa)).first

      run_get vms_url, :expand => "resources", :attributes => "bogus"

      expect_query_result(:vms, 1, 1)
      expect_result_resources_to_have_only_keys("resources", %w(id href))
      expect_result_resources_to_match_hash([{"id" => vm.id, "href" => vms_url(vm.id)}])
    end
  end

  context "Query - search vms" do
    it "by tag" do
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

  context "Query - vms" do
    it "without expand parameter" do
      api_basic_authorize
      create_vms_by_name(%w(aa bb))

      run_get vms_url

      expect_query_result(:vms, 2, 2)
      expect_result_resources_to_have_only_keys("resources", %w(href))
    end

    it "with expanding resources" do
      api_basic_authorize
      create_vms_by_name(%w(aa bb))

      run_get vms_url, :expand => "resources"

      expect_query_result(:vms, 2, 2)
      expect_result_resources_to_include_keys("resources", %w(id href guid name vendor))
    end

    it "with expanding resources and software subcollection" do
      api_basic_authorize
      vm1 = create_vms_by_name(%w(aa)).first
      FactoryGirl.create(:guest_application, :vm_or_template_id => vm1.id, :name => "LibreOffice")

      run_get vms_url, :expand => "resources,software"

      expect_query_result(:vms, 1, 1)
      expect_result_resources_to_include_keys("resources", %w(id href guid name vendor software))
    end
  end
end
