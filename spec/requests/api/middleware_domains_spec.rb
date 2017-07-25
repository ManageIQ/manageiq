describe 'Middleware Domains API' do
  let(:domain) { FactoryGirl.create :middleware_domain }

  # For some reason middleware_domains_url is not returning the full
  # url, just the path portion. This is a hack, but will do the trick.
  def domain_url
    "http://www.example.com#{middleware_domains_url(domain.id)}"
  end

  def match_id
    eq ApplicationRecord.compress_id(domain.id).to_s
  end

  describe '/' do
    it 'forbids access without an appropriate role' do
      api_basic_authorize

      run_get middleware_domains_url

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns an empty listing of domains' do
      api_basic_authorize collection_action_identifier(:middleware_domains, :read, :get)

      run_get middleware_domains_url

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        'name'      => 'middleware_domains',
        'count'     => 0,
        'resources' => [],
        'subcount'  => 0
      )
    end

    it 'returns a listing of domains' do
      domain

      api_basic_authorize collection_action_identifier(:middleware_domains, :read, :get)

      run_get middleware_domains_url

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        'name'      => 'middleware_domains',
        'count'     => 1,
        'resources' => [{
          'href' => domain_url
        }],
        'subcount'  => 1
      )
    end
  end

  describe '/:id' do
    it 'returns the attributes of one domain' do
      api_basic_authorize

      run_get middleware_domains_url(domain.id)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['id']).to match_id
      expect(response.parsed_body).to include(
        'href' => domain_url,
        'name' => domain.name
      )
    end
  end
end
