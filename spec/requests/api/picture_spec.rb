#
# Rest API Request Tests - Picture specs
#
# - Query picture and image_href of service_templates  /api/service_templates/:id?attributes=picture,picture.image_href
# - Query picture and image_href of services           /api/services/:id?attributes=picture,picture.image_href
# - Query picture and image_href of service_requests   /api/service_requests/:id?attributes=picture,picture.image_href
#
describe "Pictures" do
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
    # one pixel png image encoded in Base64
    let(:content) do
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAABGdBTUEAALGP\n"\
      "C/xhBQAAACBjSFJNAAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3Cc\n"\
      "ulE8AAAACXBIWXMAAAsTAAALEwEAmpwYAAABWWlUWHRYTUw6Y29tLmFkb2Jl\n"\
      "LnhtcAAAAAAAPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpuczptZXRhLyIg\n"\
      "eDp4bXB0az0iWE1QIENvcmUgNS40LjAiPgogICA8cmRmOlJERiB4bWxuczpy\n"\
      "ZGY9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkvMDIvMjItcmRmLXN5bnRheC1u\n"\
      "cyMiPgogICAgICA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIgogICAg\n"\
      "ICAgICAgICB4bWxuczp0aWZmPSJodHRwOi8vbnMuYWRvYmUuY29tL3RpZmYv\n"\
      "MS4wLyI+CiAgICAgICAgIDx0aWZmOk9yaWVudGF0aW9uPjE8L3RpZmY6T3Jp\n"\
      "ZW50YXRpb24+CiAgICAgIDwvcmRmOkRlc2NyaXB0aW9uPgogICA8L3JkZjpS\n"\
      "REY+CjwveDp4bXBtZXRhPgpMwidZAAAADUlEQVQIHWNgYGCwBQAAQgA+3N0+\n"\
      "xQAAAABJRU5ErkJggg==\n"
    end

    it 'rejects create without an appropriate role' do
      api_basic_authorize

      run_post pictures_url, :extension => 'png', :content => content

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

    it 'rejects a picture that is not Base64 encoded' do
      api_basic_authorize collection_action_identifier(:pictures, :create)

      run_post pictures_url, :extension => 'png', :content => 'bogus'

      expected = {
        'error' => a_hash_including(
          'kind'    => 'bad_request',
          'message' => a_string_matching(/content is not base64/),
        )
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:bad_request)
    end

    it 'requires an extension' do
      api_basic_authorize collection_action_identifier(:pictures, :create)

      run_post pictures_url, :content => content

      expected = {
        'error' => a_hash_including(
          'kind'    => 'bad_request',
          'message' => a_string_matching(/requires an extension/),
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
