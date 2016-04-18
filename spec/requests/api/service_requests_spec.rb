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
      api_basic_authorize
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
      api_basic_authorize
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

  context "as a subcollection of service orders" do
    context "with an appropriate role" do
      it "can list a service request's service orders" do
        service_order = FactoryGirl.create(:service_order, :miq_requests => [service_request])
        api_basic_authorize action_identifier(:service_requests, :read, :subcollection_actions, :get)

        url = "#{service_orders_url(service_order.id)}/service_requests"
        run_get url

        expected_href = a_string_matching("#{url}/#{service_request.id}")
        expect(response).to have_http_status(:ok)
        expect(response_hash).to include("count"     => 1,
                                         "name"      => "service_requests",
                                         "resources" => [a_hash_including("href" => expected_href)],
                                         "subcount"  => 1)
      end

      it "can show a service requests's service order" do
        service_order = FactoryGirl.create(:service_order, :miq_requests => [service_request])
        api_basic_authorize action_identifier(:service_requests, :read, :subresource_actions, :get)

        url = "#{service_orders_url(service_order.id)}/service_requests/#{service_request.id}"
        run_get url

        expect(response).to have_http_status(:ok)
        expect(response_hash).to include("id" => service_request.id, "href" => a_string_matching(url))
      end
    end

    context "without an appropriate role" do
      it "will not list a service request's service orders" do
        service_order = FactoryGirl.create(:service_order, :miq_requests => [service_request])
        api_basic_authorize

        run_get "#{service_orders_url(service_order.id)}/service_requests"

        expect(response).to have_http_status(:forbidden)
      end

      it "will not show a service request's service order" do
        service_order = FactoryGirl.create(:service_order, :miq_requests => [service_request])
        api_basic_authorize

        run_get "#{service_orders_url(service_order.id)}/service_requests/#{service_request.id}"

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
