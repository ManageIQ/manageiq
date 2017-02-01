#
# Rest API Request Tests - Picture specs
#
# - Query picture and image_href of service_templates  /api/service_templates/:id?attributes=picture,picture.image_href
# - Query picture and image_href of services           /api/services/:id?attributes=picture,picture.image_href
# - Query picture and image_href of service_requests   /api/service_requests/:id?attributes=picture,picture.image_href
#
describe "Pictures" do
  # Valid base64
  let(:content) do
    "aW1hZ2U="
  end
  let(:dialog1)  { FactoryGirl.create(:dialog, :label => "ServiceDialog1") }
  let(:ra1)      { FactoryGirl.create(:resource_action, :action => "Provision", :dialog => dialog1) }
  let(:picture)  { FactoryGirl.create(:picture, :extension => "jpg", :content => content) }
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
    expect_result_to_match_hash(response.parsed_body, "id" => source_id)
    expect_result_to_have_keys(%w(id href picture))
    expect_result_to_match_hash(response.parsed_body["picture"],
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
      api_basic_authorize action_identifier(:service_requests, :read, :resource_actions, :get)

      run_get service_requests_url(service_request.id), :attributes => "picture,picture.image_href"

      expect_result_to_include_picture_href(service_request.id)
    end
  end

  describe 'POST /api/pictures' do
    it 'rejects create without an appropriate role' do
      api_basic_authorize

      run_post pictures_url, :content => content

      expect(response).to have_http_status(:forbidden)
    end

    it 'creates a new picture' do
      api_basic_authorize collection_action_identifier(:pictures, :create)

      expected = {
        'results' => [a_hash_including('id')]
      }

      expect do
        run_post pictures_url, :extension => 'png', :content => content
      end.to change(Picture, :count).by(1)
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it 'creates multiple pictures' do
      api_basic_authorize collection_action_identifier(:pictures, :create)

      expected = {
        'results' => [a_hash_including('id'), a_hash_including('id')]
      }

      expect do
        run_post(pictures_url, gen_request(:create, [
                                             {:extension => 'png', :content => content},
                                             {:extension => 'jpg', :content => content}
                                           ]))
      end.to change(Picture, :count).by(2)
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it 'rejects a bad picture' do
      api_basic_authorize collection_action_identifier(:pictures, :create)

      run_post pictures_url, :extension => 'png', :content => 'bogus'

      expected = {
        'error' => a_hash_including(
          'kind'    => 'bad_request',
          'message' => a_string_matching(/invalid base64/),
        )
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:bad_request)
    end

    it 'requires content' do
      api_basic_authorize collection_action_identifier(:pictures, :create)

      run_post pictures_url, :extension => 'png'

      expected = {
        'error' => a_hash_including(
          'kind'    => 'bad_request',
          'message' => a_string_matching(/requires content/),
        )
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:bad_request)
    end
  end
end
