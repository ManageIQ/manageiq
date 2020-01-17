RSpec.describe ServiceTemplate do
  describe "#template_copy" do
    let(:custom_button)                  { FactoryBot.create(:custom_button, :applies_to => service_template) }
    let(:custom_button_for_service)      { FactoryBot.create(:custom_button, :applies_to_class => "Service") }
    let(:custom_button_set)              { FactoryBot.create(:custom_button_set, :owner => service_template, :set_data => set_data) }
    let(:service_template)               { FactoryBot.create(:service_template) }
    let(:service_template_ansible_tower) { FactoryBot.create(:service_template_ansible_tower) }
    let(:service_template_orchestration) { FactoryBot.create(:service_template_orchestration) }
    let(:set_data)                       { {:applies_to_class => "Service", :button_order => [custom_button.id], :applies_to_id => service_template.id} }

    def copy_template(template, name = nil)
      copy = nil
      expect do
        copy = template.public_send(*[:template_copy, name].compact)
      end.to(change { ServiceTemplate.count }.by(1))
      expect(copy.persisted?).to be(true)
      expect(copy.guid).not_to eq(template.guid)
      expect(copy.display).to be(false)
      copy
    end

    context "with given name" do
      it "without resource " do
        copy_template(service_template, "new_template")
      end

      it "with custom button copy only direct_custom_buttons" do
        custom_button
        custom_button_for_service
        expect(service_template.custom_buttons.count).to eq(2)
        new_service_template = copy_template(service_template, "new_template")
        expect(new_service_template.direct_custom_buttons.count).to eq(service_template.direct_custom_buttons.count)
      end

      it "with custom button it can copy a copy" do
        custom_button
        custom_button_for_service
        expect(service_template.custom_buttons.count).to eq(2)
        new_service_template = copy_template(service_template, "new_template")
        copy_of_copy = copy_template(new_service_template)
        expect(copy_of_copy.direct_custom_buttons.count).to eq(new_service_template.direct_custom_buttons.count)
      end

      it "with custom button set" do
        service_template.update!(:options => {:button_order => ["cbg-#{custom_button_set.id}"]})
        custom_button_set.add_member(custom_button)
        expect(service_template.custom_button_sets.count).to eq(1)
        expect(service_template.custom_button_sets.first.custom_buttons.count).to eq(1)
        expect(service_template.custom_button_sets.first.set_data).to eq(set_data)
        expect(service_template.custom_button_sets.first.children).to eq([custom_button])
        new_service_template = copy_template(service_template, "new_template")
        new_button_group = new_service_template.custom_button_sets.first
        new_button = new_service_template.custom_button_sets.first.custom_buttons.first
        expect(new_service_template.custom_button_sets.count).to eq(1)
        expect(new_button_group.set_data).not_to eq(set_data)
        expect(new_button_group.set_data[:applies_to_id]).not_to eq(service_template.custom_button_sets.first.set_data[:applies_to_id])
        expect(new_button_group.custom_buttons.count).to eq(1)
        expect(new_service_template[:options][:button_order]).to contain_exactly("cbg-#{new_button_group.id}", "cb-#{new_button.id}")
        expect(new_button_group.children).not_to eq([custom_button])
        expect(new_button_group.children).to eq(new_button_group.custom_buttons)
      end

      it "with non-copyable resource (configuration script base)" do
        service_template.add_resource(FactoryBot.create(:configuration_script_base))
        new_service_template = copy_template(service_template, "new_template")
        expect(service_template.service_resources.first.resource).not_to be(nil)
        expect(new_service_template.service_resources.first.resource).to eq(service_template.service_resources.first.resource)
        expect(ConfigurationScriptBase.count).to eq(1)
      end

      it "with non-copyable resource (ext management system)" do
        service_template.add_resource(FactoryBot.create(:ext_management_system))
        new_service_template = copy_template(service_template, "new_template")
        expect(new_service_template.service_resources.first.resource_id).to eq(service_template.service_resources.first.resource_id)
        expect(ExtManagementSystem.count).to eq(1)
        expect(service_template.service_resources.first.resource).not_to be(nil)
      end

      it "with non-copyable resource (orchestration template)" do
        service_template.add_resource(FactoryBot.create(:orchestration_template))
        new_service_template = copy_template(service_template, "new_template")
        expect(new_service_template.service_resources.first.resource_id).to eq(service_template.service_resources.first.resource_id)
        expect(OrchestrationTemplate.count).to eq(1)
        expect(service_template.service_resources.first.resource).not_to be(nil)
      end

      it "with copyable resource" do
        admin = FactoryBot.create(:user_admin)
        vm_template = FactoryBot.create(:vm_openstack, :ext_management_system => FactoryBot.create(:ext_management_system))
        ptr = FactoryBot.create(:miq_provision_request_template, :requester => admin, :src_vm_id => vm_template.id)
        service_template.add_resource(ptr)
        new_service_template = copy_template(service_template, "new_template")
        expect(MiqProvisionRequestTemplate.count).to eq(2)
        expect(new_service_template.service_resources.count).not_to be(0)
        expect(service_template.service_resources.first.resource).not_to be(nil)
      end

      it "with copyable resource copies sr options" do
        admin = FactoryBot.create(:user_admin)
        vm_template = FactoryBot.create(:vm_openstack, :ext_management_system => FactoryBot.create(:ext_management_system))
        ptr = FactoryBot.create(:miq_provision_request_template, :requester => admin, :src_vm_id => vm_template.id)
        service_template.add_resource(ptr)
        service_template.service_resources.first.update(:scaling_min => 4)
        expect(service_template.service_resources.first.scaling_min).to eq(4)
        new_service_template = copy_template(service_template, "new_template")
        expect(MiqProvisionRequestTemplate.count).to eq(2)
        expect(new_service_template.service_resources.first.scaling_min).to eq(4)
        expect(service_template.service_resources.first.resource).not_to be(nil)
      end

      it "service template ansible tower with copyable resource" do
        admin = FactoryBot.create(:user_admin)
        vm_template = FactoryBot.create(:vm_openstack, :ext_management_system => FactoryBot.create(:ext_management_system))
        ptr = FactoryBot.create(:miq_provision_request_template, :requester => admin, :src_vm_id => vm_template.id)
        service_template_ansible_tower.add_resource(ptr)
        new_service_template = copy_template(service_template_ansible_tower)
        expect(MiqProvisionRequestTemplate.count).to eq(2)
        expect(new_service_template.service_resources.count).to eq(1)
        expect(service_template_ansible_tower.service_resources.first.resource).not_to be(nil)
      end

      it "service template orchestration with copyable resource" do
        admin = FactoryBot.create(:user_admin)
        vm_template = FactoryBot.create(:vm_openstack, :ext_management_system => FactoryBot.create(:ext_management_system))
        ptr = FactoryBot.create(:miq_provision_request_template, :requester => admin, :src_vm_id => vm_template.id)
        service_template_orchestration.add_resource(ptr)
        new_service_template = copy_template(service_template_orchestration)
        expect(MiqProvisionRequestTemplate.count).to eq(2)
        expect(new_service_template.service_resources.count).to eq(1)
        expect(service_template_orchestration.service_resources.first.resource).not_to be(nil)
      end
    end

    context "without given name" do
      it "without resource" do
        new_service_template = copy_template(service_template)
        expect(new_service_template.service_resources.count).to eq(0)
        expect(service_template.service_resources.count).to eq(0)
      end

      it "with non-copyable resource (configuration_script_base)" do
        service_template.add_resource(FactoryBot.create(:configuration_script_base))
        new_service_template = copy_template(service_template)
        expect(new_service_template.service_resources.first.resource_id).to eq(service_template.service_resources.first.resource_id)
        expect(ConfigurationScriptBase.count).to eq(1)
      end

      it "with non-copyable resource (ext management system)" do
        service_template.add_resource(FactoryBot.create(:ext_management_system))
        new_service_template = copy_template(service_template)
        expect(ServiceTemplate.where("name ILIKE ?", "Copy of service%").first.service_resources.first.resource_id).to eq(service_template.service_resources.first.resource_id)
        expect(ExtManagementSystem.count).to eq(1)
        expect(new_service_template.service_resources.count).not_to be(0)
        expect(service_template.service_resources.first.resource).not_to be(nil)
      end

      it "with non-copyable resource (orchestration template)" do
        service_template.add_resource(FactoryBot.create(:orchestration_template))
        new_service_template = copy_template(service_template)
        expect(new_service_template.service_resources.first.resource_id).to eq(service_template.service_resources.first.resource_id)
        expect(OrchestrationTemplate.count).to eq(1)
        expect(new_service_template.service_resources.count).to eq(1)
        expect(service_template.service_resources.first.resource).not_to be(nil)
      end

      it "with copyable resource" do
        admin = FactoryBot.create(:user_admin)
        vm_template = FactoryBot.create(:vm_openstack, :ext_management_system => FactoryBot.create(:ext_management_system))
        ptr = FactoryBot.create(:miq_provision_request_template, :requester => admin, :src_vm_id => vm_template.id)
        service_template.add_resource(ptr)
        new_service_template = copy_template(service_template)
        expect(MiqProvisionRequestTemplate.count).to eq(2)
        expect(new_service_template.service_resources.count).to eq(1)
        expect(service_template.service_resources.first.resource).not_to be(nil)
      end
    end

    context "picture" do
      it "creates a duplicate picture" do
        service_template.picture = { :content => 'foobar', :extension => 'jpg' }
        new_template = service_template.template_copy

        expect(service_template.picture.id).to_not eq(new_template.picture.id)
        expect(service_template.picture.content).to eq(new_template.picture.content)
      end

      it "leave picture nil when source template is nil" do
        new_template = service_template.template_copy

        expect(service_template.picture).to be_nil
        expect(new_template.picture).to be_nil
      end
    end

    context "resource_actions" do
      it "duplicates resource_actions" do
        service_template.resource_actions << [
          FactoryBot.create(:resource_action, :action => "Provision"),
          FactoryBot.create(:resource_action, :action => "Retire")
        ]

        new_template = service_template.template_copy
        expect(new_template.resource_actions.pluck(:action)).to match_array(%w[Provision Retire])
      end
    end

    context "additional tenants" do
      it "duplicates additional tenants" do
        service_template.additional_tenants << [
          FactoryBot.create(:tenant),
          FactoryBot.create(:tenant, :subdomain => nil)
        ]
        expect(service_template.additional_tenants.count).to eq(2)
        new_template = service_template.template_copy
        expect(new_template.additional_tenants.count).to eq(2)
      end
    end

    context "tags" do
      it "does not duplicate tags by default" do
        service_template.tags << FactoryBot.create(:tag)
        expect(service_template.tags.count).to eq(1)

        new_template = service_template.template_copy

        expect(new_template.tags.count).to be_zero
      end

      it "duplicates tags" do
        service_template.tags << [
          FactoryBot.create(:tag),
          FactoryBot.create(:tag)
        ]
        expect(service_template.tags.count).to eq(2)

        new_template = service_template.template_copy(:copy_tags => true)

        expect(new_template.tags).to match_array(service_template.tags)
      end
    end
  end
end
