describe ServiceTemplateAnsibleTower do
  describe "#create_catalog_item" do
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
            :fqname            => ra1.fqname,
            :service_dialog_id => service_dialog.id
          },
          :retirement              => {
            :fqname            => ra2.fqname,
            :service_dialog_id => service_dialog.id
          }
        }
      }
    end

    it 'creates and returns a catalog item' do
      service_template = ServiceTemplateAnsibleTower.create_catalog_item(catalog_item_options)

      expect(service_template.name).to eq('Ansible Tower')
      expect(service_template.service_resources.count).to eq(1)
      expect(service_template.dialogs.first).to eq(service_dialog)
      expect(service_template.resource_actions.pluck(:action)).to include('Provision', 'Retirement')
      expect(service_template.job_template).to eq(configuration_script)
    end
  end
end
