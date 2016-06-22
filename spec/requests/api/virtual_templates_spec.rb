RSpec.describe 'Virtual Template API' do
  context 'virtual templates index' do
    it 'can list all the virtual templates' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :read, :get)
      _vt_list = FactoryGirl.create_list(:virtual_template, 2)

      run_get(virtual_templates_url)
      expect_query_result(:virtual_templates, 2, 2)
    end

    it 'only lists virtual templates (no other templates)' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :read, :get)
      FactoryGirl.create(:virtual_template)
      FactoryGirl.create(:template_amazon)

      run_get(virtual_templates_url)
      expect_query_result(:virtual_templates, 1, 1)
    end
  end

  context 'virtual templates create' do
    let(:template) do
      {
          action: 'create',
          name: 'create_vt',
          vendor: 'amazon',
          location: 'us-west-2',
          cloud_network_id: 0,
          cloud_subnet_id: 1,
          availability_zone_id: 2,
          ems_ref: 'aref'
      }
    end
    let(:template2) do
      {
          action: 'create',
          name: 'create_vt2',
          vendor: 'amazon',
          location: 'us-west-2',
          cloud_network_id: 0,
          cloud_subnet_id: 1,
          availability_zone_id: 2,
          ems_ref: 'aref'
      }
    end
    let(:expected_attributes) { %w(name vendor location cloud_network_id cloud_subnet_id ems_ref availability_zone_id) }

    it 'supports single virtual template creation' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :create)
      run_post(virtual_templates_url, template)

      expect_request_success
      expect_result_resources_to_include_keys('results', expected_attributes)
    end
  end

  context 'virtual template edit' do
    let(:template) { FactoryGirl.create(:virtual_template) }

    it 'supports single group edit' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :edit)
      run_post(virtual_templates_url(template.id), gen_request(:edit, name: 'updatedName'))

      expect(template.reload.name).to eq('updatedName')
    end
  end

  context 'virtual template delete' do
    let(:template) { FactoryGirl.create(:virtual_template) }

    it 'supports single virtual template delete' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :delete)

      run_delete(virtual_templates_url(template.id))
      expect_request_success_with_no_content
    end

    it 'rejects single virtual template delete for invalid templates' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :delete)

      run_delete(virtual_templates_url(99))
      expect_resource_not_found
    end
  end
end