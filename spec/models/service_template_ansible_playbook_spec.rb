RSpec.describe ServiceTemplateAnsiblePlaybook do
  let(:user)     { FactoryBot.create(:user_with_group) }
  let(:auth_one) { FactoryBot.create(:embedded_ansible_credential) }
  let(:auth_two) { FactoryBot.create(:embedded_ansible_credential) }
  let(:auth_three) { FactoryBot.create(:embedded_ansible_credential) }

  let(:script_source) { FactoryBot.create(:configuration_script_source, :manager => ems) }

  let(:service_template_catalog) { FactoryBot.create(:service_template_catalog) }
  let(:provider) { FactoryBot.create(:provider_embedded_ansible, :default_inventory => 1) }
  let(:ems)      { FactoryBot.create(:automation_manager_ansible_tower, :provider => provider) }

  let(:playbook) do
    FactoryBot.create(:embedded_playbook,
                       :configuration_script_source => script_source,
                       :manager                     => ems)
  end

  let(:job_template) do
    FactoryBot.create(:embedded_ansible_configuration_script,
                       :variables => catalog_item_options.fetch_path(:config_info, :provision, :extra_vars),
                       :manager   => ems)
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
          :become_enabled        => true,
          :verbosity             => 3,
          :credential_id         => auth_one.id,
          :network_credential_id => auth_two.id,
          :vault_credential_id   => auth_three.id,
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
            'key1' => {:default => 'val1'},
            'key2' => {:default => 'val2'}
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
                          :become_enabled  => false,
                          :verbosity       => 0,
                          :extra_vars      => {
                            'key1' => {:default => 'updated_val1'},
                            'key2' => {:default => 'updated_val2'}
                          }
                        }
                      }}
    catalog_item_options.deep_merge(changed_items)
  end

  describe '.create_catalog_item' do
    it 'creates and returns a catalog item' do
      service_template = described_class.create_catalog_item(catalog_item_options_two, user)

      expect(service_template.name).to eq(catalog_item_options_two[:name])
      expect(service_template.config_info[:provision]).to include(catalog_item_options[:config_info][:provision])
      expect(service_template.dialogs.first.name)
        .to eq(catalog_item_options.fetch_path(:config_info, :provision, :new_dialog_name))
      expect(service_template.resource_actions.first).to have_attributes(
        :action => 'Provision',
        :fqname => described_class.default_provisioning_entry_point('atomic')
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
    let(:service_template) { prebuild_service_template }

    it 'updates and returns the modified catalog item' do
      new_dialog_label = catalog_item_options_three
                         .fetch_path(:config_info, :provision, :new_dialog_name)
      expect(Dialog.where(:label => new_dialog_label)).to be_empty
      service_template.update_catalog_item(catalog_item_options_three, user)

      expect(service_template.name).to eq(catalog_item_options_three[:name])
      expect(service_template.description).to eq(catalog_item_options_three[:description])
      expect(service_template.options.fetch_path(:config_info, :provision, :extra_vars)).to include(
        'key1' => {:default => 'updated_val1'},
        'key2' => {:default => 'updated_val2'}
      )
      expect(service_template.options.fetch_path(:config_info, :provision)).to include(
        :become_enabled => false,
        :verbosity      => 0
      )
      new_dialog_record = Dialog.where(:label => new_dialog_label).first
      expect(new_dialog_record).to be_truthy
      expect(service_template.resource_actions.first.dialog.id).to eq new_dialog_record.id
    end

    it 'uses the existing dialog if :dialog_id is passed in' do
      info = catalog_item_options_three.fetch_path(:config_info, :provision)
      info[:dialog_id] = service_template.dialogs.first.id

      expect(service_template.dialogs.first.id).to eq info[:dialog_id]
      expect(service_template).to receive(:create_new_dialog).never
      service_template.update_catalog_item(catalog_item_options_three, user)
      service_template.reload

      expect(service_template.dialogs.first.id).to eq info[:dialog_id]
    end
  end

  def prebuild_service_template
    described_class.create_catalog_item(catalog_item_options_two, user)
  end
end
