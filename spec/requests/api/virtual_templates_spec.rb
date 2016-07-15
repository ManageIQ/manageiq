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
  let(:cloud_subnet) { FactoryGirl.create(:cloud_subnet) }
  let(:cloud_network) { FactoryGirl.create(:cloud_network) }
  let(:availability_zone) { FactoryGirl.create(:availability_zone_google) }
  let(:ems) { FactoryGirl.create(:ext_management_system) }
  let(:flavor) { FactoryGirl.create(:flavor_google) }

  context 'virtual templates index' do
    it 'can list all the virtual templates' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :read, :get)
      FactoryGirl.create(:virtual_template, :ems_id => ems.id)
      FactoryGirl.create(:virtual_template_google,
                         :ems_id               => ems.id,
                         :flavor_id            => flavor.id,
                         :cloud_network_id     => cloud_network.id,
                         :cloud_subnet_id      => cloud_subnet.id,
                         :availability_zone_id => availability_zone.id)

      run_get(virtual_templates_url)
      expect_query_result(:virtual_templates, 2, 2)
    end

    it 'only lists virtual templates (no other templates)' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :read, :get)
      FactoryGirl.create(:virtual_template, :ems_id => ems.id)
      FactoryGirl.create(:template_google, :ems_id => ems.id)

      run_get(virtual_templates_url)
      expect_query_result(:virtual_templates, 1, 1)
    end
  end

  context 'virtual templates create' do
    let(:google_template) do
      {
        :action               => 'create',
        :name                 => 'create_google_template',
        :vendor               => 'google',
        :location             => 'us-west-2',
        :cloud_network_id     => cloud_network.id,
        :ems_id               => ems.id,
        :flavor_id            => flavor.id,
        :cloud_subnet_id      => cloud_subnet.id,
        :availability_zone_id => availability_zone.id,
        :ems_ref              => 'i-12345',
        :type                 => 'ManageIQ::Providers::Google::CloudManager::VirtualTemplate'
      }
    end
    let(:template) do
      {
        :action               => 'create',
        :name                 => 'create_vt2',
        :vendor               => 'amazon',
        :location             => 'us-west-2',
        :cloud_network_id     => cloud_network.id,
        :ems_id               => ems.id,
        :flavor_id            => flavor.id,
        :availability_zone_id => availability_zone.id,
        :ems_ref              => 'i-12345'
      }
    end
    let(:expected_attributes) { %w(name vendor location cloud_network_id cloud_subnet_id ems_ref availability_zone_id) }

    it 'rejects creation without appropriate role' do
      api_basic_authorize

      run_post(virtual_templates_url, google_template)

      expect(response).to have_http_status(:forbidden)
    end

    it 'supports single virtual_template creation' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :create)
      run_post(virtual_templates_url, google_template)

      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys('results', expected_attributes)

      id = response.parsed_body['results'].first['id']
      expect(MiqTemplate.exists?(id)).to be_truthy
    end

    it 'supports virtual_template creation via action' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :create)
      run_post(virtual_templates_url, gen_request(:create, google_template.except(:action)))

      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys('results', expected_attributes)

      id = response.parsed_body['results'].first['id']
      expect(MiqTemplate.exists?(id)).to be_truthy
    end

    it 'rejects multiple virtual_template creation via action with the same type' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :create)
      run_post(virtual_templates_url, gen_request(:create, [template.except(:action), template.except(:action)]))

      expect_bad_request(/Virtual template may only have one per type/)
    end

    it 'rejects virtual_template creation of a duplicate type' do
      FactoryGirl.create(:virtual_template_google,
                         :ems_id               => ems.id,
                         :flavor_id            => flavor.id,
                         :cloud_network_id     => cloud_network.id,
                         :cloud_subnet_id      => cloud_subnet.id,
                         :availability_zone_id => availability_zone.id)
      api_basic_authorize collection_action_identifier(:virtual_templates, :create)
      run_post(virtual_templates_url, google_template)
      expect_bad_request(/Virtual template may only have one per type/)
    end

    it 'rejects a request without a vendor' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :create)
      run_post(virtual_templates_url, template.except(:vendor))

      expect_bad_request(/Must specify a vendor for creating a Virtual Template/)
    end

    it 'rejects a request with an href' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :create)
      run_post(virtual_templates_url, template.merge(:href => virtual_templates_url))

      expect_bad_request(/Resource id or href should not be specified/)
    end

    it 'rejects a request with an id' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :create)
      run_post(virtual_templates_url, template.merge(:id => 1))

      expect_bad_request(/Resource id or href should not be specified/)
    end
  end

  context 'virtual template edit' do
    let(:template) { FactoryGirl.create(:virtual_template, :ems_id => ems.id) }
    let(:template_google) do
      FactoryGirl.create(:virtual_template_google,
                         :ems_id               => ems.id,
                         :flavor_id            => flavor.id,
                         :cloud_network_id     => cloud_network.id,
                         :cloud_subnet_id      => cloud_subnet.id,
                         :availability_zone_id => availability_zone.id)
    end

    it 'supports single virtual_template edit' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :edit)
      run_post(virtual_templates_url(template.id), gen_request(:edit, :name => 'updatedName'))

      expect(template.reload.name).to eq('updatedName')
    end

    it 'supports multiple virtual_template edit' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :edit)
      template_id_1, template_id_2 = template.id, template_google.id

      resource_request = [
        {:href => virtual_templates_url(template_id_1), :name => 'firstEdit'},
        {:href => virtual_templates_url(template_id_2), :name => 'secondEdit'}
      ]
      resource_results = [
        {'id' => template_id_1, 'name' => 'firstEdit'},
        {'id' => template_id_2, 'name' => 'secondEdit'}
      ]

      run_post(virtual_templates_url, gen_request(:edit, resource_request))

      expect_results_to_match_hash('results', resource_results)
      expect(template.reload.name).to eq('firstEdit')
      expect(template_google.reload.name).to eq('secondEdit')
    end
  end

  context 'virtual template delete' do
    let(:template) { FactoryGirl.create(:virtual_template, :ems_id => ems.id) }
    let(:template_google) do
      FactoryGirl.create(:virtual_template_google,
                         :ems_id               => ems.id,
                         :flavor_id            => flavor.id,
                         :cloud_network_id     => cloud_network.id,
                         :cloud_subnet_id      => cloud_subnet.id,
                         :availability_zone_id => availability_zone.id)
    end

    it 'supports single virtual_template delete' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :delete)

      run_delete(virtual_templates_url(template.id))
      expect(response).to have_http_status(:no_content)
    end

    it 'supports multiple virtual_template delete' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :delete)
      template_id_1, template_id_2 = template.id, template_google.id
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
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'virtual template provision' do
    let(:virtual_template) do
      FactoryGirl.create(:virtual_template_google,
                         :ems_id               => ems.id,
                         :availability_zone_id => availability_zone.id,
                         :cloud_network_id     => cloud_network.id,
                         :flavor_id            => flavor.id)
    end
    let(:dialog) { FactoryGirl.create(:miq_dialog_provision) }
    let(:request) do
      {
        'action'    => 'provision',
        'vm_name'   => 'VirtualTemplate',
        'requester' => {
          'owner_first_name' => 'First',
          'owner_last_name'  => 'Last',
          'owner_email'      => 'email@email.com',
          'request_notes'    => 'A Test Provision'
        }
      }
    end
    let(:request_url) { virtual_templates_url(virtual_template.id).to_s }

    it 'creates an MiqProvisionRequest' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :provision)

      dialog
      run_post(request_url, request)

      expect(response).to have_http_status(:ok)
      task_id = response.parsed_body['id']
      expect(MiqProvisionRequest.exists?(task_id)).to be_truthy
    end

    it 'rejects requests without appropriate role' do
      api_basic_authorize

      run_post(request_url, request)
      expect(response).to have_http_status(:forbidden)
    end

    it 'requires a requester' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :provision)

      dialog
      run_post(request_url, request.except('requester'))
      expect_bad_request(/Requester required/)
    end

    it 'requires a VM name' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :provision)

      dialog
      run_post(request_url, request.except('vm_name'))
      expect_bad_request(/VM name required/)
    end
  end
end
