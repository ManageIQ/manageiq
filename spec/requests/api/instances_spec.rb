require "spec_helper"

RSpec.describe "Instances API" do
  include Rack::Test::Methods

  def app
    Vmdb::Application
  end

  before(:each) { init_api_spec_env }

  context "Instance index" do
    it "lists only the cloud instances (no infrastructure vms)" do
      api_basic_authorize
      instance = FactoryGirl.create(:vm_openstack)
      _vm = FactoryGirl.create(:vm_vmware)

      run_get(instances_url)

      expect_query_result(:instances, 1, 1)
      expect_result_resources_to_include_hrefs("resources", [instances_url(instance.id)])
      expect_request_success
    end
  end

  context "Instance terminate action" do
    let(:instance) { FactoryGirl.create(:vm_openstack) }
    let(:instance1) { FactoryGirl.create(:vm_openstack) }
    let(:instance2) { FactoryGirl.create(:vm_openstack) }
    let(:instance_url) { instances_url(instance.id) }
    let(:instance1_url) { instances_url(instance1.id) }
    let(:instance2_url) { instances_url(instance2.id) }
    let(:invalid_instance_url) { instances_url(999_999) }
    let(:instances_list) { [instance1_url, instance2_url] }

    it "to an invalid instance" do
      api_basic_authorize action_identifier(:instances, :terminate)

      run_post(invalid_instance_url, gen_request(:terminate))

      expect_resource_not_found
    end

    it "to an invalid instance without appropriate role" do
      api_basic_authorize

      run_post(invalid_instance_url, gen_request(:terminate))

      expect_request_forbidden
    end

    it "to a single Instance" do
      api_basic_authorize action_identifier(:instances, :terminate)

      run_post(instance_url, gen_request(:terminate))

      expect_single_action_result(:success => true, :message => /#{instance.id}.* terminating/i, :href => :instance_url)
    end

    it "to multiple Instances" do
      api_basic_authorize collection_action_identifier(:instances, :terminate)

      run_post(instances_url, gen_request(:terminate, [{"href" => instance1_url}, {"href" => instance2_url}]))

      expect_multiple_action_result(2)
      expect_result_resources_to_include_hrefs("results", :instances_list)
      expect_result_resources_to_match_key_data(
        "results",
        "message",
        [/#{instance1.id}.* terminating/i, /#{instance2.id}.* terminating/i]
      )
    end
  end
end
