describe ServiceTemplateAnsiblePlaybook do
  describe 'building_job_templates' do
    let(:user) { FactoryGirl.create(:user_with_group) }
    let(:job_template) do
      FactoryGirl.create(:configuration_script,
                         :variables => catalog_item_options.fetch_path(:config_info, :provision, :extra_vars))
    end
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

    let(:catalog_item_options_two) do
      {
        :name        => 'playbook service',
        :display     => 'false',
        :description => 'a description',
        :config_info => {
          :provision   => {
            :new_dialog_name => 'playbook dialog',
            :playbook_id     => 1,
            :extra_vars      => {
              'key1' => 'val1',
              'key2' => 'val2'
            }
          },
          :reconfigure => {
            :new_dialog_name => 'playbook dialog reconfigure',
            :playbook_id     => 5,
          },
          :retirement  => {
            :new_dialog_name => 'playbook dialog retirement',
            :playbook_id     => 3,
          },
        }
      }
    end

    it '#create_job_templates' do
      expect(described_class).to receive(:create_job_template).exactly(3).times.and_return(job_template)
      options_hash = described_class.create_job_templates(catalog_item_options_two[:name], catalog_item_options_two[:description], catalog_item_options_two[:config_info], 'system')
      [:provision, :retirement, :reconfigure].each do |action|
        expect(options_hash[action.to_sym][:configuration_template]).to eq job_template
      end
    end

    it '#create_job_template' do
      expect(described_class).to receive(:build_parameter_list).and_return([ems, {}])
      expect(ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript).to receive(:create_in_provider_queue).once.with(ems.id, {}, 'system')
      expect(MiqTask).to receive(:wait_for_taskid).with(any_args).once.and_return(instance_double('MiqTask', :task_results => {}, :status => 'Ok'))

      described_class.create_job_template(catalog_item_options[:name], catalog_item_options[:description], catalog_item_options[:config_info], 'system')
    end

    it 'create_job_template exception' do
      expect(described_class).to receive(:build_parameter_list).and_return([ems, {}])
      expect(ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript).to receive(:create_in_provider_queue).once.with(ems.id, {}, 'system')
      expect(MiqTask).to receive(:wait_for_taskid).with(any_args).once.and_raise(Exception, 'bad job template')

      expect { described_class.create_job_template(catalog_item_options[:name], catalog_item_options[:description], catalog_item_options[:config_info], 'system') }.to raise_error(Exception)
    end

    it '#build_parameter_list' do
      name = catalog_item_options[:name]
      description = catalog_item_options[:description]
      info = catalog_item_options[:config_info][:provision]
      _tower, params = described_class.build_parameter_list(name, description, info)

      expect(params).to have_attributes(
        :name               => name,
        :description        => description,
        :extra_vars         => nil,
        :credential         => '6',
        :cloud_credential   => nil,
        :network_credential => '10'
      )
    end

    it '#unique_job_template_name' do
      [:provision, :retirement, :reconfigure].each do |type|
        name = described_class.unique_job_template_name("blah", type)
        name_list = name.split('_')
        expect(name).to_not eq "blah_#{type}"
        expect(name_list.size).to eq 3
        expect(name_list).to include('blah', type.to_s)
      end
    end
  end
end
