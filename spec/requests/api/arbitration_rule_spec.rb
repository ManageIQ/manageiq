RSpec.describe 'Arbitration Rule API' do
  context 'arbitration rules index' do
    it 'rejects requests without an appropriate role' do
      api_basic_authorize

      run_get arbitration_rules_url

      expect(response).to have_http_status(:forbidden)
    end

    it 'can list arbitration rules' do
      rules = FactoryGirl.create_list(:arbitration_rule, 2)
      api_basic_authorize collection_action_identifier(:arbitration_rules, :read, :get)

      run_get arbitration_rules_url

      expect_result_resources_to_include_hrefs(
        'resources',
        rules.map { |rule| arbitration_rules_url(rule.id) }
      )
      expect(response).to have_http_status(:ok)
    end
  end

  context 'arbitration rules create' do
    let(:expression) do
      {
        'EQUAL' => {
          'field' => 'User-userid',
          'value' => 'admin'
        }
      }
    end
    let(:request_body) do
      {
        'name'      => 'admin rule',
        'operation' => 'inject'
      }
    end

    it 'can create an arbitration rule with an expression' do
      api_basic_authorize collection_action_identifier(:arbitration_rules, :create)
      body = request_body.merge('expression' => expression)
      expect do
        run_post(arbitration_rules_url, gen_request(:create, body))
      end.to change(ArbitrationRule, :count).by(1)
    end

    it 'supports multiple arbitration_rule creation' do
      api_basic_authorize collection_action_identifier(:arbitration_rules, :create)
      body = request_body.merge('expression' => expression)

      expect do
        run_post(arbitration_rules_url, gen_request(:create, [body, body]))
      end.to change(ArbitrationRule, :count).by(2)
    end

    it 'rejects a request with an href' do
      api_basic_authorize collection_action_identifier(:arbitration_rules, :create)

      run_post(arbitration_rules_url, request_body.merge(:href => arbitration_rules_url))

      expect_bad_request(/Resource id or href should not be specified/)
    end

    it 'rejects a request with an id' do
      api_basic_authorize collection_action_identifier(:arbitration_rules, :create)

      run_post(arbitration_rules_url, request_body.merge(:id => 999_999))

      expect_bad_request(/Resource id or href should not be specified/)
    end
  end

  context 'arbitration rules edit' do
    let(:rule) { FactoryGirl.create(:arbitration_rule) }

    it 'rejects edit without an appropriate role' do
      api_basic_authorize

      run_post(arbitration_rules_url(rule.id), gen_request(:edit, :name => 'edited name'))

      expect(response).to have_http_status(:forbidden)
    end

    it 'can edit a setting' do
      api_basic_authorize collection_action_identifier(:arbitration_rules, :edit)

      expect do
        run_post(arbitration_rules_url(rule.id), gen_request(:edit, :name => 'edited name'))
      end.to change { rule.reload.name }.to('edited name')
    end
  end

  context 'arbitration rules delete' do
    it 'supports single arbitration rule delete' do
      rule = FactoryGirl.create(:arbitration_rule)
      api_basic_authorize collection_action_identifier(:arbitration_rules, :delete)
      expect do
        run_delete(arbitration_rules_url(rule.id))
      end.to change(ArbitrationRule, :count).by(-1)
    end

    it 'supports multiple arbitration rule delete' do
      rules = FactoryGirl.create_list(:arbitration_rule, 2)
      hrefs = rules.map { |rule| { 'href' => arbitration_rules_url(rule.id) } }
      api_basic_authorize collection_action_identifier(:arbitration_rules, :delete)

      expect do
        run_post(arbitration_rules_url, gen_request(:delete, hrefs))
      end.to change(ArbitrationRule, :count).by(-2)
    end
  end
end
