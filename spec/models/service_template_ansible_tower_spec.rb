describe ServiceTemplateAnsibleTower do
  describe "catalog items" do
    let(:ra1) { FactoryGirl.create(:resource_action, :action => 'Provision') }
    let(:ra2) { FactoryGirl.create(:resource_action, :action => 'Retirement') }
    let(:service_dialog) { FactoryGirl.create(:dialog) }
    let(:configuration_script) { FactoryGirl.create(:configuration_script) }
    let(:catalog_item_options) do
      {
        :name         => 'Ansible Tower',
        :service_type => 'generic_ansible_tower',
        :prov_type    => 'amazon',
        :display      => 'false',
        :description  => 'a description',
        :config_info  => {
          :configuration_script_id => configuration_script.id,
          :provision               => {
            :fqname    => ra1.fqname,
            :dialog_id => service_dialog.id
          },
          :retirement              => {
            :fqname    => ra2.fqname,
            :dialog_id => service_dialog.id
          }
        }
      }
    end

    context '.create_catalog_item' do
      it 'creates and returns an ansible tower catalog item' do
        service_template = ServiceTemplateAnsibleTower.create_catalog_item(catalog_item_options)
        service_template.reload

        expect(service_template.name).to eq('Ansible Tower')
        expect(service_template.service_resources.count).to eq(1)
        expect(service_template.dialogs.first).to eq(service_dialog)
        expect(service_template.resource_actions.pluck(:action)).to match_array(%w(Provision Retirement))
        expect(service_template.job_template).to eq(configuration_script)
        expect(service_template.config_info).to eq(catalog_item_options[:config_info])
      end

      it 'validates the presence of a configuration_script_id or configuration' do
        catalog_item_options[:config_info].delete(:configuration_script_id)

        expect do
          ServiceTemplateAnsibleTower.create_catalog_item(catalog_item_options)
        end.to raise_error(StandardError, 'Must provide configuration_script_id or configuration')
      end

      it 'accepts a configuration' do
        catalog_item_options[:config_info] = { :configuration => configuration_script }
        service_template = ServiceTemplateAnsibleTower.create_catalog_item(catalog_item_options)

        expect(service_template.job_template).to eq(configuration_script)
      end
    end

    context '#update_catalog_item' do
      let(:new_configuration_script) { FactoryGirl.create(:configuration_script) }
      let(:updated_catalog_item_options) do
        {
          :name        => 'Updated Ansible Tower',
          :display     => 'false',
          :description => 'a description',
          :config_info => {
            :configuration => new_configuration_script,
            :provision     => {
              :fqname    => ra1.fqname,
              :dialog_id => service_dialog.id
            },
            :reconfigure   => {
              :fqname    => ra2.fqname,
              :dialog_id => service_dialog.id
            }
          }
        }
      end

      before do
        @catalog_item = ServiceTemplateAnsibleTower.create_catalog_item(catalog_item_options)
      end

      it 'updates the catalog item' do
        updated = @catalog_item.update_catalog_item(updated_catalog_item_options)

        expect(updated.name).to eq('Updated Ansible Tower')
        expect(updated.config_info).to eq(updated_catalog_item_options[:config_info])
        expect(updated.job_template).to eq(new_configuration_script)
        expect(updated.resource_actions.pluck(:action)).to match_array(%w(Provision Reconfigure))
      end
    end
  end

  describe '#config_info' do
    it 'returns the correct format' do
      job_template = FactoryGirl.create(:configuration_script)
      service_template = FactoryGirl.create(:service_template_ansible_tower, :job_template => job_template)
      ra = FactoryGirl.create(:resource_action, :action => 'Provision', :fqname => '/a/b/c')
      service_template.create_resource_actions(:provision => { :fqname => ra.fqname })

      expected_config_info = {
        :configuration_script_id => job_template.id,
        :provision               => {
          :fqname => ra.fqname
        }
      }
      expect(service_template.config_info).to eq(expected_config_info)
    end
  end
end
