#
# Rest API Request Tests - Provision Requests specs
#
# - Create single provision request    /api/provision_requests    normal POST
# - Create single provision request    /api/provision_requests    action "create"
# - Create multiple provision requests /api/provision_requests    action "create"
#
require 'spec_helper'

describe ApiController do
  include Rack::Test::Methods

  let(:zone)       { FactoryGirl.create(:zone, :name => "api_zone") }
  let(:miq_server) { FactoryGirl.create(:miq_server, :zone => zone) }
  let(:ems)        { FactoryGirl.create(:ems_vmware, :zone => zone) }
  let(:host)       { FactoryGirl.create(:host, :ext_management_system => ems) }
  let(:dialog)     { FactoryGirl.create(:miq_dialog_provision) }

  before(:each) do
    init_api_spec_env
  end

  def app
    Vmdb::Application
  end

  describe "Provision Requests" do
    let(:hardware) { FactoryGirl.create(:hardware, :memory_cpu => 1024) }
    let(:template) do
      FactoryGirl.create(:template_vmware,
                         :name                  => "template1",
                         :host                  => host,
                         :ext_management_system => ems,
                         :hardware              => hardware)
    end

    let(:single_provision_request) do
      {
        "template_fields" => {"guid" => template.guid},
        "vm_fields"       => {"number_of_cpus" => 1, "vm_name" => "api_test"},
        "requester"       => {"user_name" => api_config(:user)}
      }
    end

    let(:expected_attributes) { %w(id options) }
    let(:expected_hash) do
      {
        "userid"         => api_config(:user),
        "requester_name" => api_config(:user_name),
        "approval_state" => "pending_approval",
        "type"           => "MiqProvisionRequest",
        "request_type"   => "template",
        "message"        => /Provisioning/i,
        "status"         => "Ok"
      }
    end

    it "rejects requests without appropriate role" do
      api_basic_authorize

      run_post(provision_requests_url, single_provision_request)

      expect_request_forbidden
    end

    it "supports single request with normal post" do
      pending "requires actionwebservice"

      api_basic_authorize collection_action_identifier(:provision_requests, :create)

      dialog  # Create the Provisioning dialog
      run_post(provision_requests_url, single_provision_request)

      expect_request_success
      expect_result_resources_to_include_keys("results", expected_attributes)
      expect_results_to_match_hash("results", [expected_hash])

      task_id = @result["results"].first["id"]
      expect(MiqProvisionRequest.exists?(task_id)).to be_true
    end

    it "supports single request with create action" do
      pending "requires actionwebservice"

      api_basic_authorize collection_action_identifier(:provision_requests, :create)

      dialog  # Create the Provisioning dialog
      run_post(provision_requests_url, gen_request(:create, single_provision_request))

      expect_request_success
      expect_result_resources_to_include_keys("results", expected_attributes)
      expect_results_to_match_hash("results", [expected_hash])

      task_id = @result["results"].first["id"]
      expect(MiqProvisionRequest.exists?(task_id)).to be_true
    end

    it "supports multiple requests" do
      pending "requires actionwebservice"

      api_basic_authorize collection_action_identifier(:provision_requests, :create)

      dialog  # Create the Provisioning dialog
      run_post(provision_requests_url, gen_request(:create, [single_provision_request, single_provision_request]))

      expect_request_success
      expect_result_resources_to_include_keys("results", expected_attributes)
      expect_results_to_match_hash("results", [expected_hash, expected_hash])

      task_id1, task_id2 = @result["results"].collect { |r| r["id"] }
      expect(MiqProvisionRequest.exists?(task_id1)).to be_true
      expect(MiqProvisionRequest.exists?(task_id2)).to be_true
    end
  end
end
