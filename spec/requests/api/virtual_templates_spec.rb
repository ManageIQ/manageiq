#
# REST API Request Tests - Virtual Template Specs
#
# - Creating a virtual_template               /api/virtual_templates                POST
# - Creating a virtual_template via action    /api/virtual_templates                action "create"
# - Edit a virtual_template                   /api/virtual_templates/:id            action "edit"
# - Edit multiple virtual_templates           /api/virtual_templates                action "edit"
# - Delete a virtual_template by action       /api/virtual_templates/:id            action "delete"
# - Delete multiple virtual_templates         /api/virtual_templates                action "delete"
# - Delete virtual_template                   /api/virtual_templates                DELETE
# - Get list of virtual templates             /api/virtual_templates                GET
# - Get a virtual template                    /api/virtual_templates/:id            GET

RSpec.describe 'Virtual Template API' do
  context 'virtual templates index' do
    it 'can list all the virtual templates' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :read, :get)
      FactoryGirl.create(:virtual_template)
      FactoryGirl.create(:virtual_template, :generic)

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
          ems_ref: 'aref',
          type: 'ManageIQ::Providers::Amazon::CloudManager::VirtualTemplate'
      }
    end
    let(:template_2) do
      {
          action: 'create',
          name: 'create_vt2',
          vendor: 'google',
          location: 'us-west-2'
      }
    end
    let(:expected_attributes) { %w(name vendor location cloud_network_id cloud_subnet_id ems_ref availability_zone_id) }

    it 'rejects creation without appropriate role' do
      api_basic_authorize

      run_post(virtual_templates_url, template)

      expect_request_forbidden
    end

    it 'supports single virtual_template creation' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :create)
      run_post(virtual_templates_url, template)

      expect_request_success
      expect_result_resources_to_include_keys('results', expected_attributes)

      id = response_hash['results'].first['id']
      expect(MiqTemplate.exists?(id)).to be_truthy
    end

    it 'supports virtual_template creation via action' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :create)
      run_post(virtual_templates_url, gen_request(:create, template.except(:action)))

      expect_request_success
      expect_result_resources_to_include_keys('results', expected_attributes)

      id = response_hash['results'].first['id']
      expect(MiqTemplate.exists?(id)).to be_truthy
    end

    it 'rejects multiple virtual_template creation via action with the same type' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :create)
      run_post(virtual_templates_url, gen_request(:create, [template.except(:action), template.except(:action)]))

      expect_bad_request(/Virtual template may only have one per type/)
    end

    it 'rejects virtual_template creation of a duplicate type' do
      FactoryGirl.create(:virtual_template)
      api_basic_authorize collection_action_identifier(:virtual_templates, :create)
      run_post(virtual_templates_url, template)

      expect_bad_request(/Virtual template may only have one per type/)
    end

    it 'rejects unsupported virtual template vendors' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :create)
      run_post(virtual_templates_url, template_2)

      expect_bad_request(/Must specify a supported type/)
      'Unsupported Action create for the virtual_templates resource specified'
    end

    it 'rejects a request without a vendor' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :create)
      run_post(virtual_templates_url, template.except(:vendor))

      expect_bad_request(/Must specify a vendor for creating a Virtual Template/)
    end
  end

  context 'virtual template edit' do
    let(:template) { FactoryGirl.create(:virtual_template) }
    let(:template_2) {FactoryGirl.create(:virtual_template, :generic)}

    it 'supports single virtual_template edit' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :edit)
      run_post(virtual_templates_url(template.id), gen_request(:edit, name: 'updatedName'))

      expect(template.reload.name).to eq('updatedName')
    end

    it 'supports multiple virtual_template edit' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :edit)
      template_id_1, template_id_2 = template.id, template_2.id

      resource_request = [
          { href: virtual_templates_url(template_id_1), name: 'firstEdit' },
          { href: virtual_templates_url(template_id_2), name: 'secondEdit' }
      ]
      resource_results = [
          { 'id' => template_id_1, 'name' => 'firstEdit' },
          { 'id' => template_id_2, 'name' => 'secondEdit' }
      ]

      run_post(virtual_templates_url, gen_request(:edit, resource_request))

      expect_results_to_match_hash('results', resource_results)
      expect(template.reload.name).to eq('firstEdit')
      expect(template_2.reload.name).to eq('secondEdit')
    end
  end

  context 'virtual template delete' do
    let(:template) { FactoryGirl.create(:virtual_template) }
    let(:template_2) { FactoryGirl.create(:virtual_template, :generic) }

    it 'supports single virtual_template delete' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :delete)

      run_delete(virtual_templates_url(template.id))
      expect_request_success_with_no_content
    end

    it 'supports multiple virtual_template delete' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :delete)
      template_id_1, template_id_2 = template.id, template_2.id
      template_url_1, template_url_2 = virtual_templates_url(template_id_1), virtual_templates_url(template_id_2)

      run_post(virtual_templates_url, gen_request(:delete, [{'href' => template_url_1}, {'href' => template_url_2}]))

      expect_multiple_action_result(2)
      expect_result_resources_to_include_hrefs('results', [template_url_1, template_url_2])
      expect(MiqTemplate.exists?(template_id_1)).to be_falsey
      expect(MiqTemplate.exists?(template_id_2)).to be_falsey
    end

    it 'rejects single virtual_template delete for invalid templates' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :delete)

      run_delete(virtual_templates_url(99))
      expect_resource_not_found
    end
  end
end