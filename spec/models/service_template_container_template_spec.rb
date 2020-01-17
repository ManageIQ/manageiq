RSpec.describe ServiceTemplateContainerTemplate do
  let(:service_template_catalog) { FactoryBot.create(:service_template_catalog) }
  let(:container_template) { FactoryBot.create(:container_template, :ems_id => ems.id) }
  let(:ems) { FactoryBot.create(:ems_openshift) }
  let(:dialog) { FactoryBot.create(:dialog) }
  let(:dialog2) { FactoryBot.create(:dialog) }

  let(:catalog_item_options) do
    {
      :name                        => 'container_template_catalog_item',
      :description                 => 'test container template',
      :service_template_catalog_id => service_template_catalog.id,
      :display                     => true,
      :config_info                 => {
        :provision => {
          :dialog_id             => dialog.id,
          :container_template_id => container_template.id
        },
      }
    }
  end

  let(:catalog_item_options_2) do
    changed_items = {
      :name        => 'test_update_item',
      :description => 'test updated container template item',
      :config_info => {
        :provision => {
          :dialog_id => dialog2.id
        }
      }
    }
    catalog_item_options.deep_merge(changed_items)
  end

  describe '.create_catalog_item' do
    it 'creates and returns a catalog item' do
      service_template = described_class.create_catalog_item(catalog_item_options)

      expect(service_template.name).to eq(catalog_item_options[:name])
      expect(service_template.config_info[:provision]).to include(catalog_item_options[:config_info][:provision])
      expect(service_template.container_template).to eq(container_template)
      expect(service_template.resource_actions.first).to have_attributes(
        :action                 => 'Provision',
        :fqname                 => described_class.default_provisioning_entry_point('atomic'),
        :configuration_template => container_template,
        :dialog_id              => dialog.id
      )

      saved_options = catalog_item_options[:config_info]
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
  end

  describe '#update_catalog_item' do
    subject(:service_template) { described_class.create_catalog_item(catalog_item_options) }

    it 'updates and returns the modified catalog item' do
      service_template.update_catalog_item(catalog_item_options_2)

      expect(service_template.name).to eq(catalog_item_options_2[:name])
      expect(service_template.description).to eq(catalog_item_options_2[:description])
      expect(service_template.dialogs.first.id).to eq(dialog2.id)
      expect(service_template.options[:config_info][:provision]).not_to have_key(:configuration_template)
      expect(service_template.options[:config_info][:provision][:dialog_id]).to eq(dialog2.id)
    end
  end
end
