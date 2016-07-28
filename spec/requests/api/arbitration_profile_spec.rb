RSpec.describe 'Arbitration Profile API' do
  let(:ems) { FactoryGirl.create(:ext_management_system) }

  context 'arbitration defaults index' do
    it 'can list the arbitration defaults' do
      FactoryGirl.create(:arbitration_profile, :ext_management_system => ems)

      api_basic_authorize collection_action_identifier(:arbitration_profiles, :read, :get)
      run_get(arbitration_profiles_url)
      expect_query_result(:arbitration_profiles, 1, 1)
    end
  end

  context 'arbitration defaults create' do
    let(:request_body) do
      {:ems_id => ems.id,
       :name   => 'aws arbitration default'}
    end

    it 'rejects creation without appropriate role' do
      api_basic_authorize

      run_post(arbitration_profiles_url, request_body)
      expect(response).to have_http_status(:forbidden)
    end

    it 'supports single arbitration_default creation' do
      api_basic_authorize collection_action_identifier(:arbitration_profiles, :create)

      expect do
        run_post(arbitration_profiles_url, request_body)
      end.to change(ArbitrationProfile, :count).by(1)
      expect(response).to have_http_status(:ok)
    end

    it 'supports arbitration_default creation via action' do
      api_basic_authorize collection_action_identifier(:arbitration_profiles, :create)

      expect do
        run_post(arbitration_profiles_url, gen_request(:create, request_body))
      end.to change(ArbitrationProfile, :count).by(1)
      expect(response).to have_http_status(:ok)
    end

    it 'rejects a request with an href' do
      api_basic_authorize collection_action_identifier(:arbitration_profiles, :create)
      run_post(arbitration_profiles_url, request_body.merge(:href => arbitration_profiles_url))

      expect_bad_request(/Resource id or href should not be specified/)
    end

    it 'rejects a request with an id' do
      api_basic_authorize collection_action_identifier(:arbitration_profiles, :create)
      run_post(arbitration_profiles_url, request_body.merge(:id => 1))

      expect_bad_request(/Resource id or href should not be specified/)
    end
  end

  context 'arbitration defaults edit' do
    let(:cloud_subnet) { FactoryGirl.create(:cloud_subnet) }
    let(:default) do
      FactoryGirl.create(:arbitration_profile,
                         :cloud_subnet_id       => cloud_subnet.id,
                         :ext_management_system => ems)
    end

    it 'supports single arbitration_default edit' do
      subnet = FactoryGirl.create(:cloud_subnet)
      api_basic_authorize collection_action_identifier(:arbitration_profiles, :edit)

      run_post(arbitration_profiles_url(default.id), gen_request(:edit, :cloud_subnet_id => subnet.id))

      expect(default.reload.cloud_subnet_id).to eq(subnet.id)
    end

    it 'supports multiple arbitration_default edit' do
      api_basic_authorize collection_action_identifier(:arbitration_profiles, :edit)
      subnet = FactoryGirl.create(:cloud_subnet)
      ext = FactoryGirl.create(:ext_management_system)
      default_two = FactoryGirl.create(:arbitration_profile, :ext_management_system => ext)

      default_id_1, default_id_2 = default.id, default_two.id

      resource_requests = [
        {:href => arbitration_profiles_url(default_id_1), :cloud_subnet_id => subnet.id},
        {:href => arbitration_profiles_url(default_id_2), :cloud_subnet_id => subnet.id}
      ]
      resource_results = [
        {'id' => default_id_1, 'cloud_subnet_id' => subnet.id},
        {'id' => default_id_2, 'cloud_subnet_id' => subnet.id}
      ]

      run_post(arbitration_profiles_url, gen_request(:edit, resource_requests))
      expect_results_to_match_hash('results', resource_results)
      expect(default.reload.cloud_subnet_id).to eq(subnet.id)
      expect(default_two.reload.cloud_subnet_id).to eq(subnet.id)
    end
  end

  context 'arbitration_defaults delete' do
    it 'supports single arbitration_default delete' do
      arb_default = FactoryGirl.create(:arbitration_profile, :ext_management_system => ems)
      api_basic_authorize collection_action_identifier(:arbitration_profiles, :delete)

      run_delete(arbitration_profiles_url(arb_default.id))

      expect(response).to have_http_status(:no_content)
      expect(ArbitrationProfile.exists?(arb_default.id)).to be_falsey
    end

    it 'supports multiple arbitration_default delete' do
      api_basic_authorize collection_action_identifier(:arbitration_profiles, :delete)

      ems_2 = FactoryGirl.create(:ext_management_system)
      arb_default_1 = FactoryGirl.create(:arbitration_profile, :ext_management_system => ems)
      arb_default_2 = FactoryGirl.create(:arbitration_profile, :ext_management_system => ems_2)

      arb_id_1, arb_id_2 = arb_default_1.id, arb_default_2.id
      arb_url_1, arb_url_2 = arbitration_profiles_url(arb_default_1.id), arbitration_profiles_url(arb_default_2.id)

      run_post(arbitration_profiles_url, gen_request(:delete, [{'href' => arb_url_1}, {'href' => arb_url_2}]))

      expect_multiple_action_result(2)
      expect_result_resources_to_include_hrefs('results', [arb_url_1, arb_url_2])
      expect(ArbitrationProfile.exists?(arb_id_1)).to be_falsey
      expect(ArbitrationProfile.exists?(arb_id_2)).to be_falsey
    end
  end
end
