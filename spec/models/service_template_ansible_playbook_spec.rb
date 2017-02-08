describe ServiceTemplateAnsiblePlaybook do
  describe '#create_catalog_item' do
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
        :name                     => 'test_ansible_catalog_item',
        :description              => 'test ansible',
        :service_template_catalog => service_template_catalog,
        :config_info              => {
          :provision         => {
            :new_dialog_name => 'test_dialog',
            :hosts           => 'many',
            :credential      => 6,
            :playbook_id     => playbook.id,
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
      expect(service_template.resource_actions.pluck(:action)).to include('Provision')
    end
  end
end
