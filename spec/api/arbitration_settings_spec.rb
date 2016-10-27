RSpec.describe 'Arbitration Profile API' do
  context 'arbitration settings index' do
    it 'rejects request without appropriate role' do
      api_basic_authorize

      run_get arbitration_settings_url

      expect(response).to have_http_status(:forbidden)
    end

    it 'can list the arbitration settings' do
      settings = FactoryGirl.create_list(:arbitration_setting, 2)
      api_basic_authorize collection_action_identifier(:arbitration_settings, :read, :get)

      run_get arbitration_settings_url

      expect_result_resources_to_include_hrefs(
        'resources',
        settings.map { |setting| arbitration_settings_url(setting.id) }
      )
      expect(response).to have_http_status(:ok)
    end
  end

  context 'arbitration settings create' do
    let(:request_body) do
      { :name => 'test_setting', :display_name => 'Test Setting' }
    end

    it 'rejects creation without appropriate role' do
      api_basic_authorize

      run_post(arbitration_settings_url, request_body)

      expect(response).to have_http_status(:forbidden)
    end

    it 'supports single arbitration_setting creation' do
      api_basic_authorize collection_action_identifier(:arbitration_settings, :create)

      expect do
        run_post(arbitration_settings_url, request_body)
      end.to change(ArbitrationSetting, :count).by(1)

      expect(response).to have_http_status(:ok)
    end

    it 'supports multiple arbitration_setting creation' do
      api_basic_authorize collection_action_identifier(:arbitration_settings, :create)
      request_body_2 = { :name => 'test_setting_2', :display_name => 'Test Setting 2' }

      expect do
        run_post(arbitration_settings_url, gen_request(:create, [request_body, request_body_2]))
      end.to change(ArbitrationSetting, :count).by(2)

      expect(response).to have_http_status(:ok)
    end

    it 'rejects a request with an href' do
      api_basic_authorize collection_action_identifier(:arbitration_settings, :create)

      run_post(arbitration_settings_url, request_body.merge(:href => arbitration_settings_url(999_999)))

      expect_bad_request(/Resource id or href should not be specified/)
    end

    it 'rejects a request with an id' do
      api_basic_authorize collection_action_identifier(:arbitration_settings, :create)

      run_post(arbitration_settings_url, request_body.merge(:id => 999_999))

      expect_bad_request(/Resource id or href should not be specified/)
    end
  end

  context 'arbitration settings edit' do
    let(:setting) { FactoryGirl.create(:arbitration_setting) }

    it 'rejects edit without an appropriate role' do
      api_basic_authorize

      run_post(arbitration_settings_url(setting.id), gen_request(:edit, :name => 'new name'))

      expect(response).to have_http_status(:forbidden)
    end

    it 'can edit a setting' do
      api_basic_authorize collection_action_identifier(:arbitration_settings, :edit)

      expect do
        run_post(arbitration_settings_url(setting.id), gen_request(:edit, :value => 'new value'))
      end.to change { setting.reload.value }.to('new value')

      expect(response).to have_http_status(:ok)
    end
  end

  context 'arbitration_setting delete' do
    it 'rejects arbitration_setting deletion, by post action, without appropriate role' do
      api_basic_authorize

      run_post(arbitration_settings_url, gen_request(:delete, :href => arbitration_settings_url(999_999)))

      expect(response).to have_http_status(:forbidden)
    end

    it 'rejects arbitration_setting deletion without appropriate role' do
      api_basic_authorize

      run_delete(arbitration_settings_url(999_999))

      expect(response).to have_http_status(:forbidden)
    end

    it 'supports single arbitration_setting delete' do
      api_basic_authorize collection_action_identifier(:arbitration_settings, :delete)
      setting = FactoryGirl.create(:arbitration_setting)

      expect do
        run_delete(arbitration_settings_url(setting.id))
      end.to change(ArbitrationSetting, :count).by(-1)

      expect(response).to have_http_status(:no_content)
      expect(ArbitrationSetting.exists?(setting.id)).to be_falsey
    end

    it 'supports multiple arbitration_setting delete' do
      api_basic_authorize collection_action_identifier(:arbitration_settings, :delete)
      settings = FactoryGirl.create_list(:arbitration_setting, 2)
      setting_urls = settings.map { |setting| { 'href' => arbitration_settings_url(setting.id) } }

      expect do
        run_post(arbitration_settings_url, gen_request(:delete, setting_urls))
      end.to change(ArbitrationSetting, :count).by(-2)

      expect(response).to have_http_status(:ok)
    end
  end
end
