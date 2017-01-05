#
# Rest API Request Tests - Service Templates specs
#
# - Edit service template               /api/service_templates/:id    action "edit"
# - Edit multiple service templates     /api/service_templates        action "edit"
# - Delete service template             /api/service_templates/:id    DELETE
# - Delete multiple service templates   /api/service_templates        action "delete"
#
describe "Service Templates API" do
  let(:dialog1)    { FactoryGirl.create(:dialog, :label => "ServiceDialog1") }
  let(:dialog2)    { FactoryGirl.create(:dialog, :label => "ServiceDialog2") }

  let(:ra1)        { FactoryGirl.create(:resource_action, :action => "Provision", :dialog => dialog1) }
  let(:ra2)        { FactoryGirl.create(:resource_action, :action => "Retirement", :dialog => dialog2) }

  let(:picture)    { FactoryGirl.create(:picture, :extension => "jpg") }
  let(:template)   { FactoryGirl.create(:service_template, :name => "ServiceTemplate") }

  describe "Service Templates query" do
    before do
      template.resource_actions = [ra1, ra2]
      template.picture = picture
    end

    it "queries all resource actions of a Service Template" do
      api_basic_authorize

      run_get "#{service_templates_url(template.id)}/resource_actions", :expand => "resources"

      resource_actions = template.resource_actions
      expect_query_result(:resource_actions, resource_actions.count, resource_actions.count)
      expect_result_resources_to_include_data("resources", "action" => resource_actions.pluck(:action))
    end

    it "queries a specific resource action of a Service Template" do
      api_basic_authorize

      run_get "#{service_templates_url(template.id)}/resource_actions",
              :expand => "resources",
              :filter => ["action='Provision'"]

      expect_query_result(:resource_actions, 1, 2)
      expect_result_resources_to_match_hash(["id" => ra1.id, "action" => ra1.action, "dialog_id" => dialog1.id])
    end

    it "allows queries of the related picture" do
      api_basic_authorize action_identifier(:service_templates, :read, :resource_actions, :get)

      run_get service_templates_url(template.id), :attributes => "picture"

      expect_result_to_have_keys(%w(id href picture))
      expected = {"id" => template.id, "href" => service_templates_url(template.id)}
      expect_result_to_match_hash(response.parsed_body, expected)
    end

    it "allows queries of the related picture and image_href" do
      api_basic_authorize action_identifier(:service_templates, :read, :resource_actions, :get)

      run_get service_templates_url(template.id), :attributes => "picture,picture.image_href"

      expect_result_to_have_keys(%w(id href picture))
      expect_result_to_match_hash(response.parsed_body["picture"],
                                  "id"          => picture.id,
                                  "resource_id" => template.id,
                                  "image_href"  => /^http:.*#{picture.image_href}$/)
    end

    it 'returns config_info for a specific service_template resource' do
      api_basic_authorize action_identifier(:service_templates, :read, :resource_actions, :get)

      run_get(service_templates_url(template.id))

      expected = {
        'config_info' => template.config_info.deep_stringify_keys
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end
  end

  describe "Service Templates edit" do
    it "rejects requests without appropriate role" do
      api_basic_authorize

      st = FactoryGirl.create(:service_template, :name => "st")
      run_post(service_templates_url(st.id), gen_request(:edit, "name" => "sample service template"))

      expect(response).to have_http_status(:forbidden)
    end

    it "supports edits of single resource" do
      api_basic_authorize collection_action_identifier(:service_templates, :edit)

      st = FactoryGirl.create(:service_template, :name => "st1")
      run_post(service_templates_url(st.id), gen_request(:edit, "name" => "updated st1"))

      expect_single_resource_query("id" => st.id, "href" => service_templates_url(st.id), "name" => "updated st1")
      expect(st.reload.name).to eq("updated st1")
    end

    it "supports edits of multiple resources" do
      api_basic_authorize collection_action_identifier(:service_templates, :edit)

      st1 = FactoryGirl.create(:service_template, :name => "st1")
      st2 = FactoryGirl.create(:service_template, :name => "st2")

      run_post(service_templates_url, gen_request(:edit,
                                                  [{"href" => service_templates_url(st1.id), "name" => "updated st1"},
                                                   {"href" => service_templates_url(st2.id), "name" => "updated st2"}]))

      expect(response).to have_http_status(:ok)
      expect_results_to_match_hash("results",
                                   [{"id" => st1.id, "name" => "updated st1"},
                                    {"id" => st2.id, "name" => "updated st2"}])

      expect(st1.reload.name).to eq("updated st1")
      expect(st2.reload.name).to eq("updated st2")
    end
  end

  describe "Service Templates delete" do
    it "rejects requests without appropriate role" do
      api_basic_authorize

      run_post(service_templates_url, gen_request(:delete, "href" => service_templates_url(100)))

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects resource deletion without appropriate role" do
      api_basic_authorize

      run_delete(service_templates_url(100))

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects resource deletes for invalid resources" do
      api_basic_authorize collection_action_identifier(:service_templates, :delete)

      run_delete(service_templates_url(999_999))

      expect(response).to have_http_status(:not_found)
    end

    it "supports single resource deletes" do
      api_basic_authorize collection_action_identifier(:service_templates, :delete)

      st = FactoryGirl.create(:service_template, :name => "st", :description => "st description")

      run_delete(service_templates_url(st.id))

      expect(response).to have_http_status(:no_content)
      expect { st.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "supports multiple resource deletes" do
      api_basic_authorize collection_action_identifier(:service_templates, :delete)

      st1 = FactoryGirl.create(:service_template, :name => "st1", :description => "st1 description")
      st2 = FactoryGirl.create(:service_template, :name => "st2", :description => "st2 description")

      run_post(service_templates_url, gen_request(:delete,
                                                  [{"href" => service_templates_url(st1.id)},
                                                   {"href" => service_templates_url(st2.id)}]))
      expect_multiple_action_result(2)
      expect_result_resources_to_include_hrefs("results",
                                               [service_templates_url(st1.id), service_templates_url(st2.id)])

      expect { st1.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { st2.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "can delete a service template through its nested URI" do
      service_catalog = FactoryGirl.create(:service_template_catalog)
      service_template = FactoryGirl.create(:service_template, :service_template_catalog => service_catalog)
      api_basic_authorize action_identifier(:service_templates, :delete, :subresource_actions, :delete)

      expect do
        run_delete("#{service_catalogs_url(service_catalog.id)}/service_templates/#{service_template.id}")
      end.to change(ServiceTemplate, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end

  describe "service requests subcollection" do
    it "can list a service template's service requests" do
      service_template = FactoryGirl.create(:service_template)
      service_request = FactoryGirl.create(:service_template_provision_request,
                                           :requester => @user,
                                           :source    => service_template)
      api_basic_authorize(action_identifier(:service_requests, :read, :subcollection_actions, :get))

      run_get("#{service_templates_url(service_template.id)}/service_requests")

      expected = {
        "count"     => 1,
        "subcount"  => 1,
        "name"      => "service_requests",
        "resources" => [
          {
            "href" => a_string_matching(
              "#{service_templates_url(service_template.id)}/service_requests/#{service_request.id}"
            )
          }
        ]
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "Atomic Service Templates create" do
    let(:ems) { FactoryGirl.create(:ems_amazon) }
    let(:vm) { FactoryGirl.create(:vm_amazon, :ems_id => ems.id) }
    let(:flavor) { FactoryGirl.create(:flavor_amazon) }
    let(:dialog) { FactoryGirl.create(:miq_dialog_provision) }
    let(:template_parameters) do
      {
        :name         => 'Atomic Service Template',
        :type         => 'ServiceTemplate',
        :service_type => 'atomic',
        :prov_type    => 'amazon',
        :display      => 'false',
        :config_info  => {
          :miq_request_dialog_name => dialog.name,
          :placement_auto          => [true, 1],
          :number_of_vms           => [1, '1'],
          :src_vm_id               => [vm.id, vm.name],
          :vm_name                 => 'AtomicVMName',
          :schedule_type           => ["immediately", "Immediately on Approval"],
          :instance_type           => [flavor.id, flavor.name],
          :src_ems_id              => [ems.id, ems.name],
          :ae_endpoints            => {
            :provisioning => ra1.fqname,
            :retirement   => ra2.fqname
          }
        }
      }
    end

    it 'rejects requests without appropriate role' do
      api_basic_authorize

      run_post(service_templates_url, :name => 'foobar')

      expect(response).to have_http_status(:forbidden)
    end

    it 'can create a single service template' do
      api_basic_authorize collection_action_identifier(:service_templates, :create)

      expected = {
        'results' => a_collection_including(
          a_hash_including(
            'name'         => 'Atomic Service Template',
            'display'      => false,
            'service_type' => 'atomic',
            'prov_type'    => 'amazon'
          )
        )
      }

      expect do
        run_post(service_templates_url, template_parameters)
      end.to change(ServiceTemplate, :count).by(1)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'can create multiple service templates' do
      api_basic_authorize collection_action_identifier(:service_templates, :create)

      template_hash = {
        'name'         => 'Atomic Service Template',
        'display'      => false,
        'service_type' => 'atomic',
        'prov_type'    => 'amazon'
      }
      expected = {
        'results' => a_collection_including(
          a_hash_including(
            template_hash
          ),
          a_hash_including(
            template_hash
          )
        )
      }
      expect do
        run_post(service_templates_url, :action => 'create', :resources => [template_parameters, template_parameters])
      end.to change(ServiceTemplate, :count).by(2)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'can create a generic service template' do
      api_basic_authorize collection_action_identifier(:service_templates, :create)
      template_params = {
        'name'            => 'Generic Service Template',
        'service_type'    => 'atomic',
        'prov_type'       => 'generic',
        'generic_subtype' => '',
        'config_info'     => {}
      }

      expected = {
        'results' => [a_hash_including(template_params.except('config_info'))]
      }
      expect do
        run_post(service_templates_url, template_params)
      end.to change(ServiceTemplate, :count).by(1)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'can create a ServiceTemplateOrchestration' do
      api_basic_authorize collection_action_identifier(:service_templates, :create)
      orchestration_template = FactoryGirl.create(:orchestration_template)
      ems = FactoryGirl.create(:ext_management_system)
      template_params = {
        'name'         => 'Orchestration Template',
        'type'         => 'ServiceTemplateOrchestration',
        'prov_type'    => 'generic_orchestration',
        'service_type' => 'atomic',
        'config_info'  => {
          'template_id' => orchestration_template.id,
          'manager_id'  => ems.id,
        }
      }

      expected = {
        'results' => [a_hash_including(template_params.except('config_info'))]
      }
      expect do
        run_post(service_templates_url, template_params)
      end.to change(ServiceTemplateOrchestration, :count).by(1)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'can create a ServiceTemplateAnsibleTower' do
      api_basic_authorize collection_action_identifier(:service_templates, :create)
      config_script = FactoryGirl.create(:configuration_script)
      template_params = {
        'name'         => 'Ansible Tower',
        'type'         => 'ServiceTemplateAnsibleTower',
        'prov_type'    => 'generic_ansible_tower',
        'service_type' => 'atomic',
        'config_info'  => {
          'template_id' => config_script.id,
        }
      }

      expected = {
        'results' => [a_hash_including(template_params.except('config_info'))]
      }
      expect do
        run_post(service_templates_url, template_params)
      end.to change(ServiceTemplateAnsibleTower, :count).by(1)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end
  end
end
