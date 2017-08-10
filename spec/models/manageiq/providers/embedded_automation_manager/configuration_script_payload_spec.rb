describe ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScriptPayload do
  let(:miq_task) { FactoryGirl.create(:miq_task) }
  let(:user)     { FactoryGirl.create(:user_with_group) }
  let(:auth_one) { FactoryGirl.create(:authentication, :manager_ref => 6) }
  let(:auth_two) { FactoryGirl.create(:authentication, :manager_ref => 10) }

  let(:script_source) { FactoryGirl.create(:configuration_script_source, :manager => ems) }

  let(:service_template_catalog) { FactoryGirl.create(:service_template_catalog) }
  let(:provider) { FactoryGirl.create(:provider_embedded_ansible, :default_inventory => 1) }
  let(:ems)      { FactoryGirl.create(:automation_manager_ansible_tower, :provider => provider) }

  let(:playbook) do
    FactoryGirl.create(:embedded_playbook,
                       :configuration_script_source => script_source,
                       :manager                     => ems)
  end

  let(:job_template) do
    FactoryGirl.create(:embedded_ansible_configuration_script,
                       :variables => options.fetch_path(:config_info, :extra_vars),
                       :manager   => ems)
  end

  let(:options) do
    {
      :name        => 'test_ansible_catalog_item',
      :description => 'test ansible',
      :config_info => {
        :hosts                 => 'many',
        :verbosity             => 3,
        :credential_id         => auth_one.id,
        :network_credential_id => auth_two.id,
        :playbook_id           => playbook.id
      }
    }
  end

  let(:options_two) do
    options.deep_merge(
      :config_info => {
        :extra_vars => {
          'key1' => {:default => 'val1'},
          'key2' => {:default => 'val2'}
        }
      }
    )
  end

  describe 'running_playbooks' do
    it '#run' do
      expect(described_class).to receive(:create_job_template).and_return(job_template)
      expect(described_class).to receive(:launch).with(job_template, any_args, 'system')
      described_class.run(options)
    end

    it '#launch' do
      task_id = rand(10)
      expect(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScript).to receive(:launch_in_provider_queue).with(10, job_template.id, job_template.name, 'system').and_return(task_id)
      allow(MiqTask).to receive(:wait_for_taskid).with(task_id).and_return(miq_task)
      described_class.launch(job_template, 10, 'system')
    end

    it '#build_parameter_list' do
      name = options[:name]
      catalog_extra_vars = options_two
      description = options[:description]
      info = options[:config_info]
      _tower, params = described_class.send(:build_parameter_list, name, description, info)
      _tower_two, params_two = described_class.send(:build_parameter_list,
                                                    catalog_extra_vars[:name],
                                                    catalog_extra_vars[:description],
                                                    catalog_extra_vars[:config_info])

      expect(params).to have_attributes(
        :name               => name,
        :description        => description,
        :verbosity          => 3,
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
end
