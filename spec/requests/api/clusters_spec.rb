RSpec.describe 'Clusters API' do
  context 'OPTIONS /api/clusters' do
    it 'returns clusters node_types' do
      api_basic_authorize

      expected = a_hash_including("data" => {"node_types" => EmsCluster.node_types.to_s})

      run_options(clusters_url)
      expect(response.parsed_body).to match(expected)
      expect(response.headers['Access-Control-Allow-Methods']).to include('OPTIONS')
    end
  end
end
