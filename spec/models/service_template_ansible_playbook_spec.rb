describe ServiceTemplateAnsiblePlaybook do
  describe '#create_catalog_item' do
    let(:auth_one) { FactoryGirl.create(:authentication, :manager_ref => 6) }
    let(:auth_two) { FactoryGirl.create(:authentication, :manager_ref => 10) }
    let(:user) { FactoryGirl.create(:user_with_group) }
    let(:inventory_root_group) { FactoryGirl.create(:inventory_root_group) }
    let(:ems) do
      FactoryGirl.create(:automation_manager_ansible_tower, :inventory_root_groups => [inventory_root_group])
    end
    let(:config_script) { FactoryGirl.create(:configuration_script) }
    let(:script_source) { FactoryGirl.create(:configuration_script_source, :manager => ems) }
    let(:playbook) do
      FactoryGirl.create(:configuration_script_payload,
                         :configuration_script_source => script_source,
                         :manager                     => ems,
                         :inventory_root_group        => inventory_root_group,
                         :type                        => 'ManageIQ::Providers::AnsibleTower::AutomationManager::Playbook')
    end
    let(:service_template_catalog) { FactoryGirl.create(:service_template_catalog) }
    let(:catalog_item_options) do
      {
        :name                        => 'test_ansible_catalog_item',
        :description                 => 'test ansible',
        :service_template_catalog_id => service_template_catalog.id,
        :config_info                 => {
          :provision => {
            :new_dialog_name       => 'test_dialog',
            :hosts                 => 'many',
            :credential_id         => auth_one.id,
            :network_credential_id => auth_two.id,
            :playbook_id           => playbook.id,
          },
        }
      }
    end

    it '#create_catalog_item' do
      expect(ServiceTemplateAnsiblePlaybook).to receive(:create_catalog_item_queue)
      expect(MiqTask).to receive(:wait_for_taskid).with(any_args).once.and_return(instance_double('MiqTask', :task_results => {}))

      ServiceTemplateAnsiblePlaybook.create_catalog_item(catalog_item_options, nil)
    end

    it '#create_catalog_item_task' do
      expect(ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript).to receive(:create_in_provider)
      service_template = ServiceTemplateAnsiblePlaybook.create_catalog_item_task(catalog_item_options, nil)

      expect(service_template.name).to eq('test_ansible_catalog_item')
      expect(service_template.description).to eq('test ansible')
      expect(service_template.service_template_catalog_id).to eq(service_template_catalog.id)
      expect(service_template.resource_actions.pluck(:action)).to include('Provision')
    end

    it '#build_parameter_list' do
      name = catalog_item_options[:name]
      description = catalog_item_options[:description]
      info = catalog_item_options[:config_info][:provision]
      _tower, params = ServiceTemplateAnsiblePlaybook.send(:build_parameter_list, name, description, info)

      expect(params[:name]).to eq name
      expect(params[:description]).to eq description
      expect(params[:extra_vars]).to be_nil
      expect(params[:credential]).to eq '6'
      expect(params[:cloud_credential]).to be_nil
      expect(params[:network_credential]).to eq '10'
    end
  end
end
