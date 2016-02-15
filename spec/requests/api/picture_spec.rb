#
# Rest API Request Tests - Picture specs
#
# - Query picture and image_href of service_templates  /api/service_templates/:id?attributes=picture,picture.image_href
# - Query picture and image_href of services           /api/services/:id?attributes=picture,picture.image_href
# - Query picture and image_href of service_requests   /api/service_requests/:id?attributes=picture,picture.image_href
#
describe ApiController do
  let(:dialog1)  { FactoryGirl.create(:dialog, :label => "ServiceDialog1") }
  let(:ra1)      { FactoryGirl.create(:resource_action, :action => "Provision", :dialog => dialog1) }
  let(:picture)  { FactoryGirl.create(:picture, :extension => "jpg") }
  let(:template) do
    FactoryGirl.create(:service_template,
                       :name             => "ServiceTemplate",
                       :resource_actions => [ra1],
                       :picture          => picture)
  end
  let(:service) { FactoryGirl.create(:service, :service_template_id => template.id) }
  let(:service_request) do
    FactoryGirl.create(:service_template_provision_request,
                       :description => 'Service Request',
                       :requester   => @user,
                       :source_id   => template.id)
  end

  def expect_result_to_include_picture_href(source_id)
    expect_result_to_match_hash(response_hash, "id" => source_id)
    expect_result_to_have_keys(%w(id href picture))
    expect_result_to_match_hash(response_hash["picture"],
                                "id"          => picture.id,
                                "resource_id" => template.id,
                                "image_href"  => /^http:.*#{picture.image_href}$/)
  end

  describe "Queries of Service Templates" do
    it "allows queries of the related picture and image_href" do
      api_basic_authorize action_identifier(:service_templates, :read, :resource_actions, :get)

      run_get service_templates_url(template.id), :attributes => "picture,picture.image_href"

      expect_result_to_include_picture_href(template.id)
    end
  end

  describe "Queries of Services" do
    it "allows queries of the related picture and image_href" do
      api_basic_authorize action_identifier(:services, :read, :resource_actions, :get)

      run_get services_url(service.id), :attributes => "picture,picture.image_href"

      expect_result_to_include_picture_href(service.id)
    end
  end

  describe "Queries of Service Requests" do
    it "allows queries of the related picture and image_href" do
      api_basic_authorize

      run_get service_requests_url(service_request.id), :attributes => "picture,picture.image_href"

      expect_result_to_include_picture_href(service_request.id)
    end
  end
end
