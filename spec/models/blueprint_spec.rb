describe Blueprint do
  subject { FactoryGirl.build(:blueprint) }

  let(:admin)                      { FactoryGirl.create(:user_admin) }
  let(:button_in_a_set)            { FactoryGirl.create(:custom_button, :applies_to => catalog_bundle) }
  let(:catalog)                    { FactoryGirl.create(:service_template_catalog) }
  let(:custom_button_set)          { FactoryGirl.create(:custom_button_set) }
  let(:dialog)                     { FactoryGirl.create(:dialog_with_tab_and_group_and_field) }
  let(:direct_custom_button)       { FactoryGirl.create(:custom_button, :applies_to => catalog_bundle) }
  let(:provision_request_template) { FactoryGirl.create(:miq_provision_request_template, :requester => admin, :src_vm_id => vm_template.id) }
  let(:resource_action_1)          { FactoryGirl.create(:resource_action, :dialog => dialog) }
  let(:resource_action_2)          { FactoryGirl.create(:resource_action, :dialog => dialog) }
  let(:vm_template)                { FactoryGirl.create(:template) }

  let(:catalog_vm_provisioning) do
    FactoryGirl.create(:service_template, :name => 'Service Template Vm Provisioning').tap do |item|
      add_and_save_service(item, provision_request_template)
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

  it 'is taggable' do
    expect(subject).to respond_to(:tag_with)
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
      expect(Dialog.count).to eq(1)
      expect(subject.bundle).to eq(bundle)
      expect(bundle.display).to be_falsey
      expect(bundle.composite?).to be_truthy
      expect(bundle.service_template_catalog).to eq(catalog)
      expect(bundle.descendants.first).to eq(catalog_vm_provisioning)
      expect(bundle.dialogs.first).to eq(dialog)

      prov = bundle.resource_actions.find_by(:action => 'Provision')
      expect(prov.ae_uri).to eq(ServiceTemplate.default_provisioning_entry_point)

      retire = bundle.resource_actions.find_by(:action => 'Retirement')
      expect(retire.ae_uri).to eq(ServiceTemplate.default_retirement_entry_point)
      expect(retire.dialog).to eq(prov.dialog)
    end
  end

  describe "#content" do
    it "serializes the bundle" do
      blueprint = FactoryGirl.build(:blueprint)
      service_template_1 = FactoryGirl.create(:service_template, :name => "Foo Template")
      service_template_2 = FactoryGirl.create(:service_template, :name => "Bar Template")
      service_catalog = FactoryGirl.create(:service_template_catalog, :name => "Baz Catalog")
      service_dialog = FactoryGirl.create(:dialog_with_tab_and_group_and_field, :description => "Qux Dialog")
      automate_entrypoints = {"Provision" => "a/b/c", "Reconfigure" => "x/y/z"}
      blueprint.create_bundle(:service_templates => [service_template_1, service_template_2],
                              :service_catalog   => service_catalog,
                              :service_dialog    => service_dialog,
                              :entry_points      => automate_entrypoints)

      expected = {
        "service_templates"    => a_collection_containing_exactly(
          a_hash_including("name" => "Foo Template"),
          a_hash_including("name" => "Bar Template")
        ),
        "service_catalog"      => a_hash_including("name" => "Baz Catalog"),
        "service_dialog"       => a_hash_including("description" => "Qux Dialog"),
        "automate_entrypoints" => a_collection_containing_exactly(
          a_hash_including(
            "action"       => "Provision",
            "ae_namespace" => "a",
            "ae_class"     => "b",
            "ae_instance"  => "c"
          ),
          a_hash_including(
            "action"       => "Reconfigure",
            "ae_namespace" => "x",
            "ae_class"     => "y",
            "ae_instance"  => "z"
          )
        )
      }
      expect(blueprint.content).to include(expected)
    end
  end

  describe '#update_bundle' do
    context 'update catalog items' do
      it 'adds the first catalog item' do
        bundle = subject.update_bundle(:service_templates => [catalog_vm_provisioning])
        expect(bundle.descendants.first).to eq(catalog_vm_provisioning)
      end

      it 'adds the second catalog item' do
        bundle = subject.update_bundle(:service_templates => [catalog_vm_provisioning])
        expect(bundle.descendants.size).to eq(1)

        bundle = subject.update_bundle(:service_templates => [bundle.descendants.first, catalog_orchestration])
        expect(bundle.descendants.size).to eq(2)
        expect(bundle.descendants).to include(catalog_vm_provisioning, catalog_orchestration)
      end

      it 'removes an existing catalog item' do
        bundle = subject.update_bundle(:service_templates => [catalog_vm_provisioning, catalog_orchestration])
        expect(bundle.descendants.size).to eq(2)
        expect(ServiceTemplate.count).to eq(3)

        bundle = subject.update_bundle(:service_templates => [catalog_orchestration])
        expect(bundle.descendants.size).to eq(1)
        expect(ServiceTemplate.count).to eq(3)
        expect(bundle.descendants.first).to eq(catalog_orchestration)
      end
    end

    context 'update service catalog' do
      it do
        bundle = subject.update_bundle(:service_catalog => catalog)
        expect(bundle.service_template_catalog).to eq(catalog)

        another_catalog = FactoryGirl.create(:service_template_catalog, :name => 'another catalog')
        bundle = subject.update_bundle(:service_catalog => another_catalog)
        expect(bundle.service_template_catalog).to eq(another_catalog)
      end
    end

    context 'update entry points' do
      it do
        bundle = subject.update_bundle(:entry_points => {'Provision' => 'a/b/c'})
        expect(bundle.resource_actions.find_by(:action => 'Provision').fqname).to eq('/a/b/c')

        bundle = subject.update_bundle(:entry_points => {'Provision' => 'x/y/z'})
        expect(bundle.resource_actions.find_by(:action => 'Provision').fqname).to eq('/x/y/z')

        bundle = subject.update_bundle(:entry_points => {'Retirement' => 'm/n/o'})
        expect(bundle.resource_actions.find_by(:action => 'Retirement').fqname).to eq('/m/n/o')
        expect(bundle.resource_actions.count).to eq(1)
      end
    end

    context 'update dialog' do
      before do
        subject.update_bundle(:entry_points => {'Provision' => 'a/b/c'}, :service_dialog => dialog)
      end

      it 'uses the new dialog' do
        another_dialog = FactoryGirl.create(:dialog_with_tab_and_group_and_field, :label => 'another dialog')
        bundle = subject.update_bundle(:service_dialog => another_dialog)
        expect(Dialog.count).to eq(2)
        expect(bundle.dialogs.count).to eq(1)
        expect(bundle.dialogs.first).to eq(another_dialog)
      end
    end
  end
end

def add_and_save_service(p, c)
  p.add_resource(c)
  p.service_resources.each(&:save)
end
