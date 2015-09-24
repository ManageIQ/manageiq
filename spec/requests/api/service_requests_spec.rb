#
# Rest API Request Tests - Service Requests specs
#
# - Query provision_workflows from service_requests
#     GET /api/service_requests/:id?attributes=provision_workflow
#
require 'spec_helper'

describe ApiController do
  include Rack::Test::Methods

  let(:provision_dialog)    { FactoryGirl.create(:dialog, :label => "ProvisionDialog1") }
  let(:retirement_dialog)   { FactoryGirl.create(:dialog, :label => "RetirementDialog2") }

  let(:provision_ra) { FactoryGirl.create(:resource_action, :action => "Provision",  :dialog => provision_dialog) }
  let(:retire_ra)    { FactoryGirl.create(:resource_action, :action => "Retirement", :dialog => retirement_dialog) }
  let(:template)     { FactoryGirl.create(:service_template, :name => "ServiceTemplate") }

  let(:service_request) do
    FactoryGirl.create(:service_template_provision_request,
                       :userid      => api_config(:user),
                       :source_id   => template.id,
                       :source_type => template.class.name)
  end

  before(:each) do
    init_api_spec_env
  end

  def app
    Vmdb::Application
  end

  describe "Service Requests query" do
    before do
      template.resource_actions = [provision_ra, retire_ra]
      api_basic_authorize
    end

    it "can return the provision_workflow" do
      run_get service_requests_url(service_request.id), :attributes => "provision_workflow"

      expect_result_to_have_keys(%w(id href provision_workflow))
      provision_workflow = @result["provision_workflow"]
      provision_workflow.should be_kind_of(Hash)
      must_have = %w(settings requester dialog)
      expect(provision_workflow.keys & must_have).to match_array(must_have)

      expect(provision_workflow["requester"]).to eq(api_config(:user))

      settings = provision_workflow["settings"]
      expect(settings["resource_action_id"]).to eq(provision_ra.id)
      expect(settings["dialog_id"]).to eq(provision_dialog.id)

      dialog = provision_workflow["dialog"]
      expect(dialog["label"]).to eq(provision_dialog.label)
    end
  end
end
