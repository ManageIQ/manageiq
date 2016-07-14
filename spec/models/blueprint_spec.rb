describe Blueprint do
  let(:subject) { FactoryGirl.create(:blueprint) }

  let(:catalog_vm_provisioning) do
    admin = FactoryGirl.create(:user_admin)
    vm_template = FactoryGirl.create(:template)
    ptr = FactoryGirl.create(:miq_provision_request_template, :requester => admin, :src_vm_id => vm_template.id)
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

  let(:dialog) do
    dialog       = FactoryGirl.create(:dialog, :label => 'dialog')
    dialog_tab   = FactoryGirl.create(:dialog_tab, :label => 'tab')
    dialog_group = FactoryGirl.create(:dialog_group, :label => 'group')
    dialog_field = FactoryGirl.create(:dialog_field, :label => 'field 1', :name => "field_1")

    dialog.dialog_tabs << dialog_tab
    dialog_tab.dialog_groups << dialog_group
    dialog_group.dialog_fields << dialog_field

    dialog_group.save
    dialog_tab.save
    dialog.save
    dialog
  end

  context 'blueprint with a bundle' do
    let!(:catalog_bundle) do
      subject.update_attribute(:status, 'published')
      catalog_vm_provisioning.update_attribute(:blueprint, subject)
      catalog_orchestration.update_attribute(:blueprint, subject)
      FactoryGirl.create(:service_template, :name => 'Service Template Bundle', :display => true, :blueprint => subject).tap do |bundle|
        bundle.resource_actions =
          [FactoryGirl.create(:resource_action, :dialog => dialog), FactoryGirl.create(:resource_action, :dialog => dialog)]
        add_and_save_service(bundle, catalog_vm_provisioning)
        add_and_save_service(bundle, catalog_orchestration)
      end
    end

    describe '#bundle' do
      it 'returns the top level service template as the bundle' do
        expect(subject.bundle).to eq(catalog_bundle)
      end
    end

    describe '#deep_copy' do
      it "copies a blueprint and its service templates" do
        new_bp = subject.deep_copy(:name => 'cloned bp')
        expect(ExtManagementSystem.count).to eq(1)
        expect(OrchestrationTemplate.count).to eq(1)
        expect(ResourceAction.count).to eq(10)
        expect(MiqRequest.count).to eq(2)
        expect(ServiceResource.count).to eq(10)
        expect(ServiceTemplate.count).to eq(6)
        expect(Dialog.count).to eq(2)
        expect(new_bp.bundle.name).to eq(catalog_bundle.name)
        expect(new_bp.bundle.display).to be_falsey
        expect(new_bp.status).to be_nil
      end
    end
  end
end

def add_and_save_service(p, c)
  p.add_resource(c)
  p.service_resources.each(&:save)
end
