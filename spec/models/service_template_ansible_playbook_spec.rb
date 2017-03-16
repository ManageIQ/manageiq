describe ServiceTemplateAnsiblePlaybook do
  let(:user)     { FactoryGirl.create(:user_with_group) }
  let(:auth_one) { FactoryGirl.create(:authentication, :manager_ref => 6) }
  let(:auth_two) { FactoryGirl.create(:authentication, :manager_ref => 10) }

  let(:script_source) { FactoryGirl.create(:configuration_script_source, :manager => ems) }

  let(:inventory_root_group) { FactoryGirl.create(:inventory_root_group, :name => 'Demo Inventory') }
  let(:service_template_catalog) { FactoryGirl.create(:service_template_catalog) }
  let(:ems) do
    FactoryGirl.create(:automation_manager_ansible_tower, :inventory_root_groups => [inventory_root_group])
  end

  let(:playbook) do
    FactoryGirl.create(:embedded_playbook,
                       :configuration_script_source => script_source,
                       :manager                     => ems,
                       :inventory_root_group        => inventory_root_group)
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

  let(:catalog_item_options_three) do
    changed_items = { :name        => 'test_update_ansible_item',
                      :description => 'test updated ansible item',
                      :config_info => {
                        :provision => {
                          :new_dialog_name => 'test_dialog_updated',
                          :extra_vars      => {
                            'key1' => 'updated_val1',
                            'key2' => 'updated_val2'
                          }
                        }
                      }}
    catalog_item_options.deep_merge(changed_items)
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
      expect(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScript)
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
      expect(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScript)
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

  describe '.create_catalog_item' do
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

      saved_options = catalog_item_options_two[:config_info].deep_merge(:provision => {:dialog_id => service_template.dialogs.first.id})
      expect(service_template.options[:config_info]).to include(saved_options)
    end
  end

  describe '.validate_config_info' do
    context 'provisioning entry point is given' do
      it 'keeps the given entry point' do
        opts = described_class.send(:validate_config_info, :provision => {:fqname => 'a/b/c'})
        expect(opts[:provision][:fqname]).to eq('a/b/c')
      end
    end

    context 'provisioning entry point is not given' do
      it 'sets the default entry point' do
        opts = described_class.send(:validate_config_info, :provision => {})
        expect(opts[:provision][:fqname]).to eq(described_class.default_provisioning_entry_point('atomic'))
      end
    end

    context 'retirement entry point is given' do
      it 'keeps the given entry point' do
        opts = described_class.send(:validate_config_info, :retirement => {:fqname => 'a/b/c'})
        expect(opts[:retirement][:fqname]).to eq('a/b/c')
      end
    end

    context 'retirement entry point is not given' do
      it 'sets the default entry point' do
        opts = described_class.send(:validate_config_info, {})
        expect(opts[:retirement][:fqname]).to eq(described_class.default_retirement_entry_point)
      end
    end

    context 'with remove_resources in retirement option' do
      it 'sets the corresponding entry point' do
        %w(yes_without_playbook no_without_playbook no_with_playbook pre_with_playbook post_with_playbook).each do |opt|
          opts = described_class.send(:validate_config_info, :retirement => {:remove_resources => opt})
          expect(opts[:retirement][:fqname]).to eq(described_class.const_get(:RETIREMENT_ENTRY_POINTS)[opt])
        end
      end
    end
  end

  describe '#update_catalog_item' do
    it 'updates and returns the modified catalog item' do
      service_template = prebuild_service_template
      new_dialog_label = catalog_item_options_three
                         .fetch_path(:config_info, :provision, :new_dialog_name)
      expect(Dialog.where(:label => new_dialog_label)).to be_empty
      expect(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScript).to receive(:update_in_provider_queue).once
      service_template.update_catalog_item(catalog_item_options_three, user)

      expect(service_template.name).to eq(catalog_item_options_three[:name])
      expect(service_template.description).to eq(catalog_item_options_three[:description])
      expect(service_template.options.fetch_path(:config_info, :provision, :extra_vars)).to have_attributes(
        'key1' => 'updated_val1',
        'key2' => 'updated_val2'
      )
      new_dialog_record = Dialog.where(:label => new_dialog_label).first
      expect(new_dialog_record).to be_truthy
      expect(service_template.resource_actions.first.dialog.id).to eq new_dialog_record.id
    end

    it 'uses the existing dialog if :service_dialog_id is passed in' do
      service_template = prebuild_service_template
      info = catalog_item_options_three.fetch_path(:config_info, :provision)
      info.delete(:new_dialog_name)
      info[:service_dialog_id] = service_template.dialogs.first.id

      expect(service_template.dialogs.first.id).to eq info[:service_dialog_id]
      expect(described_class).to receive(:create_new_dialog).never
      expect(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScript).to receive(:update_in_provider_queue).once

      service_template.update_catalog_item(catalog_item_options_three, user)
      service_template.reload

      expect(service_template.dialogs.first.id).to eq info[:service_dialog_id]
    end

    def prebuild_service_template
      expect(described_class)
        .to receive(:create_job_templates).and_return(:provision => {:configuration_template => job_template})
      service_template = described_class.create_catalog_item(catalog_item_options_two, user)
      expect(service_template).to receive(:job_template)
        .and_return(job_template).at_least(:once)
      service_template
    end
  end
end
