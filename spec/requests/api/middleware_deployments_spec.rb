describe 'Middleware Deployments API' do
  let(:deployment) { FactoryGirl.create(:middleware_deployment) }

  # For some reason middleware_deployments_url is not returning the full
  # url, just the path portion. This is a hack, but will do the trick.
  def deployment_url
    "http://www.example.com#{middleware_deployments_url(deployment.id)}"
  end

  describe '/' do
    it 'forbids access without an appropriate role' do
      api_basic_authorize

      run_get middleware_deployments_url

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns an empty listing of deployments' do
      api_basic_authorize collection_action_identifier(:middleware_deployments, :read, :get)

      run_get middleware_deployments_url

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        'name'      => 'middleware_deployments',
        'count'     => 0,
        'resources' => [],
        'subcount'  => 0
      )
    end

    it 'returns a a listing of deployments' do
      deployment

      api_basic_authorize collection_action_identifier(:middleware_deployments, :read, :get)

      run_get middleware_deployments_url

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        'name'      => 'middleware_deployments',
        'count'     => 1,
        'resources' => [{
          'href' => deployment_url
        }],
        'subcount'  => 1
      )
    end
  end

  describe '/:id' do
    it 'returns the attributes of one deployment' do
      api_basic_authorize

      run_get middleware_deployments_url(deployment.id)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        'href'   => deployment_url,
        'id'     => deployment.id.to_s,
        'ems_id' => deployment.ems_id.to_s,
        'name'   => deployment.name
      )
    end
  end
end
