RSpec.describe 'Cloud Networks API' do
  context 'cloud networks index' do
    it 'rejects request without appropriate role' do
      api_basic_authorize

      run_get cloud_networks_url

      expect(response).to have_http_status(:forbidden)
    end

    it 'can list cloud networks' do
      FactoryGirl.create_list(:cloud_network, 2)
      api_basic_authorize collection_action_identifier(:cloud_networks, :read, :get)

      run_get cloud_networks_url

      expect_query_result(:cloud_networks, 2)
      expect(response).to have_http_status(:ok)
    end
  end

  context 'Providers cloud_networks subcollection' do
    let(:provider) { FactoryGirl.create(:ems_amazon_with_cloud_networks) }
    let(:provider_url) { providers_url(provider.id) }
    let(:providers_cloud_networks_url) { "#{provider_url}/cloud_networks" }

    it 'queries Providers cloud_networks' do
      cloud_network_ids = provider.cloud_networks.pluck(:id)
      api_basic_authorize collection_action_identifier(:providers, :read, :get)

      run_get providers_cloud_networks_url, :expand => 'resources'

      expect_query_result(:cloud_networks, 2)
      expect_result_resources_to_include_data('resources', 'id' => cloud_network_ids)
    end

    it "will not list cloud networks of a provider without the appropriate role" do
      api_basic_authorize

      run_get providers_cloud_networks_url

      expect(response).to have_http_status(:forbidden)
    end

    it 'queries individual provider cloud_network' do
      api_basic_authorize collection_action_identifier(:providers, :read, :get)
      network = provider.cloud_networks.first
      cloud_network_url = "#{providers_cloud_networks_url}/#{network.id}"

      run_get cloud_network_url

      expect_single_resource_query('name' => network.name, 'id' => network.id, 'ems_ref' => network.ems_ref)
    end

    it "will not show the cloud network of a provider without the appropriate role" do
      api_basic_authorize
      network = provider.cloud_networks.first
      cloud_network_url = "#{providers_cloud_networks_url}/#{network.id}"

      run_get cloud_network_url

      expect(response).to have_http_status(:forbidden)
    end

    it 'successfully returns providers on query when providers do not have cloud_networks attribute' do
      FactoryGirl.create(:ems_openshift) # Openshift does not respond to #cloud_networks
      FactoryGirl.create(:ems_amazon_with_cloud_networks) # Provider with cloud networks
      api_basic_authorize collection_action_identifier(:providers, :read, :get)

      run_get providers_url, :expand => 'resources,cloud_networks'

      expected = {
        'resources' => a_collection_including(
          a_hash_including(
            'type'           => 'ManageIQ::Providers::Amazon::CloudManager',
            'cloud_networks' => a_collection_including
          ),
          a_hash_including(
            'type' => 'ManageIQ::Providers::Openshift::ContainerManager'
          )
        )
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'returns empty resources array when querying on a provider with no cloud_networks attribute' do
      openshift = FactoryGirl.create(:ems_openshift)
      openshift_cloud_networks_url = "#{providers_url(openshift.id)}/cloud_networks"

      api_basic_authorize collection_action_identifier(:providers, :read, :get)

      run_get openshift_cloud_networks_url, :expand => 'resources'

      expected = {
        'name'      => 'cloud_networks',
        'count'     => 0,
        'subcount'  => 0,
        'resources' => []
      }

      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end
  end
end
