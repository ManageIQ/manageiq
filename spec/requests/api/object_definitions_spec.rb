RSpec.describe 'ObjectDefinitions API' do
  let(:object_def) { FactoryGirl.create(:generic_object_definition, :name => 'foo') }

  describe 'GET /api/object_definitions' do
    it 'does not list object definitions without an appropriate role' do
      api_basic_authorize

      run_get(object_definitions_url)

      expect(response).to have_http_status(:forbidden)
    end

    it 'lists all generic object definitions with an appropriate role' do
      api_basic_authorize collection_action_identifier(:object_definitions, :read, :get)

      expected = {
        'count'     => 1,
        'subcount'  => 1,
        'name'      => 'object_definitions',
        'resources' => [
          hash_including('href' => a_string_matching(object_definitions_url(object_def.id)))
        ]
      }
      run_get(object_definitions_url)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end
  end

  describe 'GET /api/object_definitions/:id' do
    it 'does not let you query object definitions without an appropriate role' do
      api_basic_authorize

      run_get(object_definitions_url(object_def.id))

      expect(response).to have_http_status(:forbidden)
    end

    it 'can query an object definition by its id' do
      api_basic_authorize collection_action_identifier(:object_definitions, :read, :get)

      expected = {
        'id'   => object_def.compressed_id,
        'name' => object_def.name
      }
      run_get(object_definitions_url(object_def.id))

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'can query an object definition by its name' do
      api_basic_authorize collection_action_identifier(:object_definitions, :read, :get)

      expected = {
        'id'   => object_def.compressed_id,
        'name' => object_def.name
      }
      run_get(object_definitions_url(object_def.name))

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'raises a record not found error if no object definition is found' do
      api_basic_authorize collection_action_identifier(:object_definitions, :read, :get)

      run_get(object_definitions_url('bar'))

      expect(response).to have_http_status(:not_found)
    end
  end
end
