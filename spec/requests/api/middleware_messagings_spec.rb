describe 'Middleware Messagings API' do
  let(:messaging) { FactoryGirl.create(:middleware_messaging) }

  # For some reason middleware_messagings_url is not returning the full
  # url, just the path portion. This is a hack, but will do the trick.
  def messaging_url
    "http://www.example.com#{middleware_messagings_url(messaging.id)}"
  end

  def match_id
    eq ApplicationRecord.compress_id(messaging.id).to_s
  end

  describe '/' do
    it 'forbids access without an appropriate role' do
      api_basic_authorize

      run_get middleware_messagings_url

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns an empty listing of messagings' do
      api_basic_authorize collection_action_identifier(:middleware_messagings, :read, :get)

      run_get middleware_messagings_url

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        'name'      => 'middleware_messagings',
        'count'     => 0,
        'resources' => [],
        'subcount'  => 0
      )
    end

    it 'returns a a listing of messagings' do
      messaging

      api_basic_authorize collection_action_identifier(:middleware_messagings, :read, :get)

      run_get middleware_messagings_url

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        'name'      => 'middleware_messagings',
        'count'     => 1,
        'resources' => [{
          'href' => messaging_url
        }],
        'subcount'  => 1
      )
    end
  end

  describe '/:id' do
    it 'returns the attributes of one messaging' do
      api_basic_authorize

      run_get middleware_messagings_url(messaging.id)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['id']).to match_id
      expect(response.parsed_body).to include('href' => messaging_url)
    end
  end
end
