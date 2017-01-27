RSpec.describe 'Authentications API' do
  describe 'GET/api/authentications' do
    it 'lists all the authentication configuration script bases with an appropriate role' do
      auth = FactoryGirl.create(:authentication)
      api_basic_authorize collection_action_identifier(:authentications, :read, :get)

      run_get(authentications_url)

      expected = {
        'count'     => 1,
        'subcount'  => 1,
        'name'      => 'authentications',
        'resources' => [hash_including('href' => a_string_matching(authentications_url(auth.id)))]
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it 'forbids access to authentication configuration script bases without an appropriate role' do
      api_basic_authorize

      run_get(authentications_url)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /api/authentications/:id' do
    it 'will show an authentication configuration script base' do
      auth = FactoryGirl.create(:authentication)
      api_basic_authorize action_identifier(:authentications, :read, :resource_actions, :get)

      run_get(authentications_url(auth.id))

      expected = {
        'href' => a_string_matching(authentications_url(auth.id))
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it 'forbids access to an authentication configuration script base' do
      auth = FactoryGirl.create(:authentication)
      api_basic_authorize

      run_get(authentications_url(auth.id))

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /api/authentications' do
    it 'will delete an authentication' do
      auth = FactoryGirl.create(:authentication)
      api_basic_authorize collection_action_identifier(:authentications, :delete, :post)

      expected = {
        'results' => [a_hash_including('success' => true)]
      }
      expect do
        run_post(authentications_url, :action => 'delete', :resources => [{ 'id' => auth.id }])
      end.to change(Authentication, :count).by(-1)
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it 'will forbid deletion to an authentication without appropriate role' do
      auth = FactoryGirl.create(:authentication)
      api_basic_authorize

      run_post(authentications_url, :action => 'delete', :resources => [{ 'id' => auth.id }])
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /api/authentications/:id' do
    it 'will delete an authentication' do
      auth = FactoryGirl.create(:authentication)
      api_basic_authorize action_identifier(:authentications, :delete, :resource_actions, :post)

      expect do
        run_post(authentications_url(auth.id), :action => 'delete')
      end.to change(Authentication, :count).by(-1)
      expect(response.parsed_body).to include('success' => true)
      expect(response).to have_http_status(:ok)
    end

    it 'will not delete an authentication without an appropriate role' do
      auth = FactoryGirl.create(:authentication)
      api_basic_authorize

      run_post(authentications_url(auth.id), :action => 'delete')

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'DELETE /api/authentications/:id' do
    it 'will delete an authentication' do
      auth = FactoryGirl.create(:authentication)
      api_basic_authorize action_identifier(:authentications, :delete, :resource_actions, :delete)

      expect do
        run_delete(authentications_url(auth.id))
      end.to change(Authentication, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it 'will not delete an authentication without an appropriate role' do
      auth = FactoryGirl.create(:authentication)
      api_basic_authorize

      run_delete(authentications_url(auth.id))

      expect(response).to have_http_status(:forbidden)
    end
  end
end
