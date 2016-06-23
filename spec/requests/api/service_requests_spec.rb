#
# Rest API Request Tests - Service Requests specs
#
# - Query provision_dialog from service_requests
#     GET /api/service_requests/:id?attributes=provision_dialog
#
# - Query provision_dialog from services
#     GET /api/services/:id?attributes=provision_dialog
#
describe ApiController do
  let(:provision_dialog1)    { FactoryGirl.create(:dialog, :label => "ProvisionDialog1") }
  let(:retirement_dialog2)   { FactoryGirl.create(:dialog, :label => "RetirementDialog2") }

  let(:provision_ra) { FactoryGirl.create(:resource_action, :action => "Provision",  :dialog => provision_dialog1) }
  let(:retire_ra)    { FactoryGirl.create(:resource_action, :action => "Retirement", :dialog => retirement_dialog2) }
  let(:template)     { FactoryGirl.create(:service_template, :name => "ServiceTemplate") }

  let(:service_request) do
    FactoryGirl.create(:service_template_provision_request,
                       :requester   => @user,
                       :source_id   => template.id,
                       :source_type => template.class.name)
  end

  let(:request_task) { FactoryGirl.create(:miq_request_task, :miq_request => service_request) }
  let(:service) { FactoryGirl.create(:service, :name => "Service", :miq_request_task => request_task) }

  def expect_result_to_have_provision_dialog
    expect_result_to_have_keys(%w(id href provision_dialog))
    provision_dialog = response_hash["provision_dialog"]
    expect(provision_dialog).to be_kind_of(Hash)
    expect(provision_dialog).to have_key("label")
    expect(provision_dialog).to have_key("dialog_tabs")
    expect(provision_dialog["label"]).to eq(provision_dialog1.label)
  end

  def expect_result_to_have_user_email(email)
    expect_request_success
    expect_result_to_have_keys(%w(id href user))
    expect(response_hash["user"]["email"]).to eq(email)
  end

  describe "Service Requests query" do
    before do
      template.resource_actions = [provision_ra, retire_ra]
      api_basic_authorize action_identifier(:service_requests, :read, :resource_actions, :get)
    end

    it "can return the provision_dialog" do
      run_get service_requests_url(service_request.id), :attributes => "provision_dialog"

      expect_result_to_have_provision_dialog
    end

    it "can return the request's user.email" do
      @user.update_attributes!(:email => "admin@api.net")
      run_get service_requests_url(service_request.id), :attributes => "user.email"

      expect_result_to_have_user_email(@user.email)
    end
  end

  describe "Service query" do
    before do
      template.resource_actions = [provision_ra, retire_ra]
      api_basic_authorize action_identifier(:services, :read, :resource_actions, :get)
    end

    it "can return the provision_dialog" do
      run_get services_url(service.id), :attributes => "provision_dialog"

      expect_result_to_have_provision_dialog
    end

    it "can return the request's user.email" do
      @user.update_attributes!(:email => "admin@api.net")
      run_get services_url(service.id), :attributes => "user.email"

      expect_result_to_have_user_email(@user.email)
    end
  end

  context "Service requests approval" do
    let(:svcreq1) do
      FactoryGirl.create(:service_template_provision_request,
                         :requester   => @user,
                         :source_id   => template.id,
                         :source_type => template.class.name)
    end
    let(:svcreq2) do
      FactoryGirl.create(:service_template_provision_request,
                         :requester   => @user,
                         :source_id   => template.id,
                         :source_type => template.class.name)
    end
    let(:svcreq1_url)  { service_requests_url(svcreq1.id) }
    let(:svcreq2_url)  { service_requests_url(svcreq2.id) }
    let(:svcreqs_list) { [svcreq1_url, svcreq2_url] }

    it "supports approving a request" do
      api_basic_authorize collection_action_identifier(:service_requests, :approve)

      run_post(svcreq1_url, gen_request(:approve, :reason => "approve reason"))

      expected_msg = "Service request #{svcreq1.id} approved"
      expect_single_action_result(:success => true, :message => expected_msg, :href => :svcreq1_url)
    end

    it "supports denying a request" do
      api_basic_authorize collection_action_identifier(:service_requests, :approve)

      run_post(svcreq2_url, gen_request(:deny, :reason => "deny reason"))

      expected_msg = "Service request #{svcreq2.id} denied"
      expect_single_action_result(:success => true, :message => expected_msg, :href => :svcreq2_url)
    end

    it "supports approving multiple requests" do
      api_basic_authorize collection_action_identifier(:service_requests, :approve)

      run_post(service_requests_url, gen_request(:approve, [{"href" => svcreq1_url, "reason" => "approve reason"},
                                                            {"href" => svcreq2_url, "reason" => "approve reason"}]))

      expect_multiple_action_result(2)
      expect_result_resources_to_include_hrefs("results", :svcreqs_list)
      expect_result_resources_to_match_key_data(
        "results",
        "message",
        [/Service request #{svcreq1.id} approved/i, /Service request #{svcreq2.id} approved/i]
      )
    end

    it "supports denying multiple requests" do
      api_basic_authorize collection_action_identifier(:service_requests, :approve)

      run_post(service_requests_url, gen_request(:deny, [{"href" => svcreq1_url, "reason" => "deny reason"},
                                                         {"href" => svcreq2_url, "reason" => "deny reason"}]))

      expect_multiple_action_result(2)
      expect_result_resources_to_include_hrefs("results", :svcreqs_list)
      expect_result_resources_to_match_key_data(
        "results",
        "message",
        [/Service request #{svcreq1.id} denied/i, /Service request #{svcreq2.id} denied/i]
      )
    end
  end
end
