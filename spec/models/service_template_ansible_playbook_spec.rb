describe ServiceTemplateAnsiblePlaybook do
  let(:user)     { FactoryGirl.create(:user_with_group) }
  let(:auth_one) { FactoryGirl.create(:authentication, :manager_ref => 6) }
  let(:auth_two) { FactoryGirl.create(:authentication, :manager_ref => 10) }

  let(:config_script) { FactoryGirl.create(:configuration_script) }
  let(:script_source) { FactoryGirl.create(:configuration_script_source, :manager => ems) }

  let(:inventory_root_group) { FactoryGirl.create(:inventory_root_group) }
  let(:service_template_catalog) { FactoryGirl.create(:service_template_catalog) }
  let(:ems) do
    FactoryGirl.create(:automation_manager_ansible_tower, :inventory_root_groups => [inventory_root_group])
  end

  let(:playbook) do
    FactoryGirl.create(:configuration_script_payload,
                       :configuration_script_source => script_source,
                       :manager                     => ems,
                       :inventory_root_group        => inventory_root_group,
                       :type                        => 'ManageIQ::Providers::AnsibleTower::AutomationManager::Playbook')
  end

  let(:job_template) do
    FactoryGirl.create(:configuration_script,
                       :variables => catalog_item_options.fetch_path(:config_info, :provision, :extra_vars))
  end

  let(:catalog_item_options) do
    {
      :name                        => 'test_ansible_catalog_item',
      :description                 => 'test ansible',
      :service_template_catalog_id => service_template_catalog.id,
      :display                     => true,
      :config_info                 => {
        :provision => {
          :new_dialog_name       => 'test_dialog',
          :hosts                 => 'many',
          :credential_id         => auth_one.id,
          :network_credential_id => auth_two.id,
          :playbook_id           => playbook.id
        },
      }
    }
  end

  let(:catalog_item_options_two) do
    catalog_item_options.deep_merge(
      :config_info => {
        :provision  => {
          :extra_vars => {
            'key1' => 'val1',
            'key2' => 'val2'
          }
        },
        :retirement => {
          :credential_id => auth_one.id,
          :playbook_id   => 3,
        },
      }
    )
  end

  describe 'building_job_templates' do
    it '#create_job_templates' do
      expect(described_class).to receive(:create_job_template).exactly(2).times.and_return(job_template)
      options_hash = described_class.send(:create_job_templates,
                                          catalog_item_options_two[:name],
                                          catalog_item_options_two[:description],
                                          catalog_item_options_two[:config_info], 'system')
      [:provision, :retirement].each do |action|
        expect(options_hash[action.to_sym][:configuration_template]).to eq job_template
      end
    end

    it '#create_job_template' do
      expect(described_class).to receive(:build_parameter_list).and_return([ems, {}])
      expect(ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript)
        .to receive(:create_in_provider_queue).once.with(ems.id, {}, 'system')
      expect(MiqTask).to receive(:wait_for_taskid).with(any_args).once.and_return(
        instance_double('MiqTask', :task_results => {}, :status => 'Ok')
      )

      described_class.send(:create_job_template,
                           catalog_item_options[:name],
                           catalog_item_options[:description],
                           catalog_item_options[:config_info],
                           'system')
    end

    it 'create_job_template exception' do
      expect(described_class).to receive(:build_parameter_list).and_return([ems, {}])
      expect(ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript)
        .to receive(:create_in_provider_queue).once.with(ems.id, {}, 'system')
      expect(MiqTask).to receive(:wait_for_taskid).with(any_args).once.and_raise(Exception, 'bad job template')

      expect do
        described_class.send(:create_job_template,
                             catalog_item_options[:name],
                             catalog_item_options[:description],
                             catalog_item_options[:config_info],
                             'system')
      end.to raise_error(Exception)
    end

    it '#build_parameter_list' do
      name = catalog_item_options[:name]
      catalog_extra_vars = catalog_item_options_two
      description = catalog_item_options[:description]
      info = catalog_item_options[:config_info][:provision]
      _tower, params = described_class.send(:build_parameter_list, name, description, info)
      _tower_two, params_two = described_class.send(:build_parameter_list,
                                                    catalog_extra_vars[:name],
                                                    catalog_extra_vars[:description],
                                                    catalog_extra_vars[:config_info][:provision])

      expect(params).to have_attributes(
        :name               => name,
        :description        => description,
        :credential         => '6',
        :network_credential => '10'
      )

      expect(params.keys).to_not include(:extra_vars, :cloud_credentials)
      expect(params_two.keys).to include(:extra_vars)
      expect(JSON.parse(params_two[:extra_vars])).to have_attributes(
        'key1' => 'val1',
        'key2' => 'val2'
      )
    end
  end

  describe '#create_catalog_item' do
    it 'creates and returns a catalog item' do
      expect(described_class)
        .to receive(:create_job_templates).and_return(:provision => {:configuration_template => job_template})
      service_template = described_class.create_catalog_item(catalog_item_options_two, user)

      expect(service_template.name).to eq(catalog_item_options_two[:name])
      expect(service_template.config_info[:provision]).to include(catalog_item_options[:config_info][:provision])
      expect(service_template.dialogs.first.name)
        .to eq(catalog_item_options.fetch_path(:config_info, :provision, :new_dialog_name))
      expect(service_template.resource_actions.first).to have_attributes(
        :action                 => 'Provision',
        :fqname                 => described_class.default_provisioning_entry_point('atomic'),
        :configuration_template => job_template
      )
    end
  end
end
