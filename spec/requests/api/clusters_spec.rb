RSpec.describe 'Clusters API' do
  context 'OPTIONS /api/clusters' do
    it 'returns clusters node_types' do
      expected_data = {"node_types" => EmsCluster.node_types.to_s}

      run_options(clusters_url)
      expect_options_results(:clusters, expected_data)
    end
  end
end
