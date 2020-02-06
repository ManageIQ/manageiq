RSpec.describe ServiceTemplateOrchestration do
  subject { FactoryBot.create(:service_template_orchestration) }

  describe '#create_subtasks' do
    it 'does not need subtasks' do
      expect(subject.create_subtasks(nil, nil).size).to eq(0)
    end
  end

  describe "#orchestration_template" do
    let(:first_orch_template) { FactoryBot.create(:orchestration_template) }
    let(:second_orch_template) { FactoryBot.create(:orchestration_template) }

    it "initially reads a nil orchestration template" do
      expect(subject.orchestration_template).to be_nil
    end

    it "adds an orchestration template" do
      subject.orchestration_template = first_orch_template
      expect(subject.orchestration_template).to eq(first_orch_template)
    end

    it "replaces the existing orchestration template" do
      subject.orchestration_template = first_orch_template
      subject.orchestration_template = second_orch_template

      expect(subject.orchestration_template).to eq(second_orch_template)
      expect(subject.orchestration_template).not_to eq(first_orch_template)
    end

    it "clears the existing orchestration template" do
      subject.orchestration_template = first_orch_template
      subject.orchestration_template = nil

      expect(subject.orchestration_template).to be_nil
    end

    it "clears invalid orchestration template" do
      subject.orchestration_template = first_orch_template
      first_orch_template.delete

      subject.save!
      subject.reload
      expect(subject.orchestration_template).to be_nil
    end
  end

  describe "#orchestration_manager" do
    let(:ems_amazon) { FactoryBot.create(:ems_amazon) }
    let(:ems_openstack) { FactoryBot.create(:ems_openstack) }

    it "initially reads a nil orchestration manager" do
      expect(subject.orchestration_manager).to be_nil
    end

    it "adds an orchestration manager" do
      subject.orchestration_manager = ems_openstack
      expect(subject.orchestration_manager).to eq(ems_openstack)
    end

    it "replaces the existing orchestration manager" do
      subject.orchestration_manager = ems_openstack
      subject.orchestration_manager = ems_amazon

      expect(subject.orchestration_manager).to eq(ems_amazon)
      expect(subject.orchestration_manager).not_to eq(ems_openstack)
    end

    it "clears the existing orchestration manager" do
      subject.orchestration_manager = ems_openstack
      subject.orchestration_manager = nil

      expect(subject.orchestration_manager).to be_nil
    end

    it "clears invalid orchestration manager" do
      subject.orchestration_manager = ems_amazon
      ems_amazon.delete

      subject.save!
      subject.reload
      expect(subject.orchestration_manager).to be_nil
    end
  end

  describe "#my_zone" do
    context "with orchestration manager" do
      let(:ems_amazon) { FactoryBot.create(:ems_amazon) }
      before { subject.orchestration_manager = ems_amazon }

      it "takes the zone from orchestration manager" do
        expect(subject.my_zone).to eq(ems_amazon.my_zone)
      end
    end

    context 'without orchestration manager' do
      it "takes the zone from MiqServer" do
        allow(MiqServer).to receive(:my_zone).and_return('default_zone')
        expect(subject.my_zone).to eq('default_zone')
      end
    end
  end

  let(:ra1) { FactoryBot.create(:resource_action, :action => 'Provision') }
  let(:ra2) { FactoryBot.create(:resource_action, :action => 'Retirement') }
  let(:service_dialog) { FactoryBot.create(:dialog) }
  let(:template) { FactoryBot.create(:orchestration_template) }
  let(:manager) { FactoryBot.create(:ext_management_system) }
  let(:catalog_item_options) do
    {
      :name         => 'Orchestration Template',
      :service_type => 'atomic',
      :prov_type    => 'generic_orchestration',
      :display      => 'false',
      :description  => 'a description',
      :config_info  => {
        :template_id => template.id,
        :manager_id  => manager.id,
        :provision   => {
          :fqname    => ra1.fqname,
          :dialog_id => service_dialog.id
        },
        :retirement  => {
          :fqname    => ra2.fqname,
          :dialog_id => service_dialog.id
        }
      }
    }
  end

  describe '.create_catalog_item' do
    it 'creates and returns an orchestration service template' do
      service_template = ServiceTemplateOrchestration.create_catalog_item(catalog_item_options)
      service_template.reload

      expect(service_template.name).to eq('Orchestration Template')
      expect(service_template.dialogs.first).to eq(service_dialog)
      expect(service_template.orchestration_template).to eq(template)
      expect(service_template.orchestration_manager).to eq(manager)
      expect(service_template.resource_actions.pluck(:action)).to include('Provision', 'Retirement')
      expect(service_template.config_info).to eq(catalog_item_options[:config_info])
    end

    it 'requires both a template_id and manager_id' do
      catalog_item_options[:config_info].delete(:template_id)

      expect do
        ServiceTemplateOrchestration.create_catalog_item(catalog_item_options)
      end.to raise_error(StandardError, 'Must provide both template_id and manager_id or manager and template')
    end

    it 'requires both a template and a manager' do
      catalog_item_options[:config_info] = { :manager => manager }

      expect do
        ServiceTemplateOrchestration.create_catalog_item(catalog_item_options)
      end.to raise_error(StandardError, 'Must provide both template_id and manager_id or manager and template')
    end

    it 'accepts a manager and a template' do
      catalog_item_options[:config_info] = { :manager => manager, :template => template }

      service_template = ServiceTemplateOrchestration.create_catalog_item(catalog_item_options)
      expect(service_template.orchestration_template).to eq(template)
      expect(service_template.orchestration_manager).to eq(manager)
    end
  end

  describe '#update_catalog_item' do
    let(:new_template) { FactoryBot.create(:orchestration_template) }
    let(:new_manager) { FactoryBot.create(:ext_management_system) }
    let(:updated_catalog_item_options) do
      {
        :name        => 'Updated Orchestration Template',
        :display     => 'false',
        :description => 'a description',
        :config_info => {
          :template_id => new_template.id,
          :manager_id  => new_manager.id,
          :provision   => {
            :fqname    => ra1.fqname,
            :dialog_id => service_dialog.id
          },
          :reconfigure => {
            :fqname    => ra2.fqname,
            :dialog_id => service_dialog.id
          }
        }
      }
    end

    before do
      @catalog_item = ServiceTemplateOrchestration.create_catalog_item(catalog_item_options)
    end

    it 'updates the catalog item' do
      updated = @catalog_item.update_catalog_item(updated_catalog_item_options)

      expect(updated.name).to eq('Updated Orchestration Template')
      expect(updated.config_info).to eq(updated_catalog_item_options[:config_info])
      expect(updated.orchestration_template).to eq(new_template)
      expect(updated.orchestration_manager).to eq(new_manager)
      expect(updated.resource_actions.pluck(:action)).to match_array(%w(Provision Reconfigure))
    end

    it 'requires both template and manager id' do
      updated_catalog_item_options[:config_info].delete(:manager_id)
      expect do
        @catalog_item.update_catalog_item(updated_catalog_item_options)
      end.to raise_error(StandardError, 'Must provide both template_id and manager_id or manager and template')
    end

    it 'can accept manager and template objects on update' do
      updated_catalog_item_options[:config_info].delete(:manager_id)
      updated_catalog_item_options[:config_info].delete(:manager_id)
      updated_catalog_item_options[:config_info].merge!(:template => new_template, :manager => new_manager)
      updated = @catalog_item.update_catalog_item(updated_catalog_item_options)

      expect(updated.orchestration_template).to eq(new_template)
      expect(updated.orchestration_manager).to eq(new_manager)
    end

    it 'allows for update without the presence of config_info' do
      expect do
        @catalog_item.update_catalog_item(:name => 'new_name')
      end.to change(@catalog_item, :name)
      expect(@catalog_item.reload.name).to eq('new_name')
    end
  end

  describe '#config_info' do
    it 'returns the correct format' do
      template = FactoryBot.create(:orchestration_template)
      manager = FactoryBot.create(:ext_management_system)
      service_template = FactoryBot.create(:service_template_orchestration,
                                            :orchestration_template => template,
                                            :orchestration_manager  => manager)
      ra = FactoryBot.create(:resource_action, :action => 'Provision', :fqname => '/a/b/c')
      service_template.create_resource_actions(:provision => { :fqname => ra.fqname })

      expected_config_info = {
        :template_id => template.id,
        :manager_id  => manager.id,
        :provision   => {
          :fqname => ra.fqname
        }
      }
      expect(service_template.config_info).to eq(expected_config_info)
    end
  end
end
