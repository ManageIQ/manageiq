#
# Rest API Request Tests - Service Requests specs
#
# - Query provision_dialog from service_requests
#     GET /api/service_requests/:id?attributes=provision_dialog
#
require 'spec_helper'

describe ApiController do
  include Rack::Test::Methods

  let(:provision_dialog1)    { FactoryGirl.create(:dialog, :label => "ProvisionDialog1") }
  let(:retirement_dialog2)   { FactoryGirl.create(:dialog, :label => "RetirementDialog2") }

  let(:provision_ra) { FactoryGirl.create(:resource_action, :action => "Provision",  :dialog => provision_dialog1) }
  let(:retire_ra)    { FactoryGirl.create(:resource_action, :action => "Retirement", :dialog => retirement_dialog2) }
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

    it "can return the provision_dialog" do
      run_get service_requests_url(service_request.id), :attributes => "provision_dialog"

      expect_result_to_have_keys(%w(id href provision_dialog))
      provision_dialog = @result["provision_dialog"]
      provision_dialog.should be_kind_of(Hash)
      expect(provision_dialog).to have_key("label")
      expect(provision_dialog).to have_key("dialog_tabs")
      expect(provision_dialog["label"]).to eq(provision_dialog1.label)
    end
  end
end
