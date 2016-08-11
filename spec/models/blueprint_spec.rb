describe Blueprint do
  subject { FactoryGirl.build(:blueprint) }

  let(:admin)                    { FactoryGirl.create(:user_admin) }
  let(:button_in_a_set)          { FactoryGirl.create(:custom_button, :applies_to => catalog_bundle) }
  let(:catalog)                  { FactoryGirl.create(:service_template_catalog) }
  let(:custom_button_set)        { FactoryGirl.create(:custom_button_set) }
  let(:dialog)                   { FactoryGirl.create(:dialog, :label => 'dialog').tap { |d| d.dialog_tabs << dialog_tab } }
  let(:dialog_field)             { FactoryGirl.create(:dialog_field, :label => 'field 1', :name => "field_1") }
  let(:dialog_group)             { FactoryGirl.create(:dialog_group, :label => 'group').tap { |dg| dg.dialog_fields << dialog_field } }
  let(:dialog_tab)               { FactoryGirl.create(:dialog_tab, :label => 'tab').tap { |dt| dt.dialog_groups << dialog_group } }
  let(:direct_custom_button)     { FactoryGirl.create(:custom_button, :applies_to => catalog_bundle) }
  let(:ptr)                      { FactoryGirl.create(:miq_provision_request_template, :requester => admin, :src_vm_id => vm_template.id) }
  let(:resource_action_1)        { FactoryGirl.create(:resource_action, :dialog => dialog) }
  let(:resource_action_2)        { FactoryGirl.create(:resource_action, :dialog => dialog) }
  let(:vm_template)              { FactoryGirl.create(:template) }

  let(:catalog_vm_provisioning) do
    FactoryGirl.create(:service_template, :name => 'Service Template Vm Provisioning').tap do |item|
      add_and_save_service(item, ptr)
      item.resource_actions = [FactoryGirl.create(:resource_action)]
    end
  end

  let(:catalog_orchestration) do
    FactoryGirl.create(:service_template, :name => 'Service Template Item').tap do |item|
      add_and_save_service(item, FactoryGirl.create(:orchestration_template))
      add_and_save_service(item, FactoryGirl.create(:ext_management_system))
      item.resource_actions = [FactoryGirl.create(:resource_action)]
    end
  end

  let(:catalog_bundle) do
    FactoryGirl.create(:service_template, :name => 'Service Template Bundle', :display => true, :blueprint => subject)
  end

  context 'blueprint with a bundle' do
    before do
      subject.update_attributes(:status => 'published')
      catalog_vm_provisioning.update_attributes(:blueprint => subject)
      catalog_orchestration.update_attributes(:blueprint => subject)
      catalog_bundle.resource_actions = [resource_action_1, resource_action_2]
      add_and_save_service(catalog_bundle, catalog_vm_provisioning)
      add_and_save_service(catalog_bundle, catalog_orchestration)
      direct_custom_button
      catalog_bundle.custom_button_sets << custom_button_set.tap { |cbs| cbs.add_member(button_in_a_set) }
    end

    describe '#bundle' do
      it 'returns the top level service template as the bundle' do
        expect(subject.bundle).to eq(catalog_bundle)
      end
    end

    describe '#deep_copy' do
      it "copies a blueprint and its service templates" do
        new_bp = subject.deep_copy(:name => 'cloned bp')
        expect(CustomButton.count).to          eq(4)
        expect(CustomButtonSet.count).to       eq(2)
        expect(Dialog.count).to                eq(2)
        expect(ExtManagementSystem.count).to   eq(1)
        expect(MiqRequest.count).to            eq(2)
        expect(OrchestrationTemplate.count).to eq(1)
        expect(ResourceAction.count).to        eq(10)
        expect(ServiceResource.count).to       eq(10)
        expect(ServiceTemplate.count).to       eq(6)
        expect(new_bp.bundle.name).to          eq(catalog_bundle.name)
        expect(new_bp.bundle.display).to       be_falsey
        expect(new_bp.status).to               be_nil

        new_service_template = new_bp.send(:service_templates).find_by(:name => 'Service Template Bundle')
        expect(new_service_template.custom_buttons.count).to                          eq(1)
        expect(new_service_template.custom_button_sets.count).to                      eq(1)
        expect(new_service_template.custom_button_sets.first.custom_buttons.count).to eq(1)
        expect(new_service_template.custom_buttons).to_not                            include(direct_custom_button)
        expect(new_service_template.custom_button_sets).to_not                        include(custom_button_set)
        expect(new_service_template.custom_button_sets.first.custom_buttons).to_not   include(button_in_a_set)
      end
    end
  end

  describe '#create_bundle' do
    it 'create a bundle from existing items' do
      bundle = subject.create_bundle(:service_templates => [catalog_vm_provisioning],
                                     :service_dialog    => dialog,
                                     :service_catalog   => catalog)
      expect(Dialog.count).to eq(2)
      expect(subject.bundle).to eq(bundle)
      expect(bundle.display).to be_falsey
      expect(bundle.composite?).to be_truthy
      expect(bundle.service_template_catalog).to eq(catalog)

      expect(bundle.descendants.first.name).to eq(catalog_vm_provisioning.name)
      expect(bundle.descendants.first.id).not_to eq(catalog_vm_provisioning.id)

      prov = bundle.resource_actions.find_by(:action => 'Provision')
      expect(prov.ae_uri).to eq(ServiceTemplate.default_provisioning_entry_point)

      retire = bundle.resource_actions.find_by(:action => 'Retirement')
      expect(retire.ae_uri).to eq(ServiceTemplate.default_retirement_entry_point)
      expect(retire.dialog).to eq(prov.dialog)
    end
  end
end

def add_and_save_service(p, c)
  p.add_resource(c)
  p.service_resources.each(&:save)
end
