describe ServiceTemplate do
  describe "#template_copy" do
    let(:service_template_ansible_tower) { FactoryBot.create(:service_template_ansible_tower) }
    let(:service_template_orchestration) { FactoryBot.create(:service_template_orchestration) }
    let(:custom_button) { FactoryBot.create(:custom_button, :applies_to => @st1) }
    let(:custom_button_for_service) { FactoryBot.create(:custom_button, :applies_to_class => "Service") }
    let(:custom_button_set) { FactoryBot.create(:custom_button_set, :owner => @st1) }
    before do
      @st1 = FactoryBot.create(:service_template)
    end

    context "with given name" do
      it "without resource " do
        expect(ServiceTemplate.count).to eq(1)
        @st1.template_copy("new_template")
        expect(ServiceTemplate.count).to eq(2)
        new_service_template = ServiceTemplate.find_by(:name => "new_template")
        expect(new_service_template.display).to be(false)
        expect(new_service_template.guid).not_to eq(@st1.guid)
      end

      it "with custom button copy only direct_custom_buttons" do
        custom_button
        custom_button_for_service
        expect(@st1.custom_buttons.count).to eq(2)
        number_of_service_templates = ServiceTemplate.count
        @st1.template_copy("new_template")
        expect(ServiceTemplate.count).to eq(number_of_service_templates + 1)
        new_service_template = ServiceTemplate.find_by(:name => "new_template")
        expect(new_service_template.display).to be(false)
        expect(new_service_template.guid).not_to eq(@st1.guid)
        expect(new_service_template.direct_custom_buttons.count).to eq(@st1.direct_custom_buttons.count)
      end

      it "with custom button it can copy a copy" do
        custom_button
        custom_button_for_service
        expect(@st1.custom_buttons.count).to eq(2)
        number_of_service_templates = ServiceTemplate.count
        @st1.template_copy("new_template")
        new_service_template = ServiceTemplate.find_by(:name => "new_template")
        new_service_template.template_copy("Copy of a copy")
        expect(ServiceTemplate.count).to eq(number_of_service_templates + 2)
        copy_of_copy = ServiceTemplate.find_by(:name => "Copy of a copy")
        expect(copy_of_copy.display).to be(false)
        expect(copy_of_copy.guid).not_to eq(new_service_template.guid)
        expect(copy_of_copy.direct_custom_buttons.count).to eq(new_service_template.direct_custom_buttons.count)
      end

      it "with custom button set" do
        custom_button_set.add_member(custom_button)
        expect(@st1.custom_button_sets.count).to eq(1)
        @st1.template_copy("new_template")
        new_service_template = ServiceTemplate.find_by(:name => "new_template")
        expect(ServiceTemplate.count).to eq(2)
        expect(new_service_template.display).to be(false)
        expect(new_service_template.guid).not_to eq(@st1.guid)
        expect(new_service_template.custom_button_sets.count).to eq(1)
      end

      it "with non-copyable resource (configuration script base)" do
        @st1.add_resource(FactoryBot.create(:configuration_script_base))
        expect(ServiceTemplate.count).to eq(1)
        @st1.template_copy("new_template")
        new_service_template = ServiceTemplate.find_by(:name => "new_template")
        expect(ServiceTemplate.count).to eq(2)
        expect(@st1.service_resources.first.resource).not_to be(nil)
        expect(new_service_template.service_resources.first.resource).to eq(@st1.service_resources.first.resource)
        expect(ConfigurationScriptBase.count).to eq(1)
        expect(new_service_template.display).to be(false)
        expect(new_service_template.guid).not_to eq(@st1.guid)
      end

      it "with non-copyable resource (ext management system)" do
        @st1.add_resource(FactoryBot.create(:ext_management_system))
        expect(ServiceTemplate.count).to eq(1)
        @st1.template_copy("new_template")
        new_service_template = ServiceTemplate.find_by(:name => "new_template")
        expect(ServiceTemplate.count).to eq(2)
        expect(new_service_template.service_resources.first.resource_id).to eq(@st1.service_resources.first.resource_id)
        expect(ExtManagementSystem.count).to eq(1)
        expect(new_service_template.guid).not_to eq(@st1.guid)
        expect(new_service_template.display).to be(false)
        expect(@st1.service_resources.first.resource).not_to be(nil)
      end

      it "with non-copyable resource (orchestration template)" do
        @st1.add_resource(FactoryBot.create(:orchestration_template))
        expect(ServiceTemplate.count).to eq(1)
        @st1.template_copy("new_template")
        new_service_template = ServiceTemplate.find_by(:name => "new_template")
        expect(ServiceTemplate.count).to eq(2)
        expect(new_service_template.service_resources.first.resource_id).to eq(@st1.service_resources.first.resource_id)
        expect(OrchestrationTemplate.count).to eq(1)
        expect(new_service_template.guid).not_to eq(@st1.guid)
        expect(new_service_template.display).to be(false)
        expect(@st1.service_resources.first.resource).not_to be(nil)
      end

      it "with copyable resource" do
        admin = FactoryBot.create(:user_admin)
        vm_template = FactoryBot.create(:vm_openstack, :ext_management_system => FactoryBot.create(:ext_management_system))
        ptr = FactoryBot.create(:miq_provision_request_template, :requester => admin, :src_vm_id => vm_template.id)
        @st1.add_resource(ptr)
        expect(ServiceTemplate.count).to eq(1)
        @st1.template_copy("new_template")
        new_service_template = ServiceTemplate.find_by(:name => "new_template")
        expect(ServiceTemplate.count).to eq(2)
        expect(MiqProvisionRequestTemplate.count).to eq(2)
        expect(new_service_template.guid).not_to eq(@st1.guid)
        expect(new_service_template.display).to be(false)
        expect(new_service_template.service_resources.count).not_to be(0)
        expect(@st1.service_resources.first.resource).not_to be(nil)
      end

      it "with copyable resource copies sr options" do
        admin = FactoryBot.create(:user_admin)
        vm_template = FactoryBot.create(:vm_openstack, :ext_management_system => FactoryBot.create(:ext_management_system))
        ptr = FactoryBot.create(:miq_provision_request_template, :requester => admin, :src_vm_id => vm_template.id)
        @st1.add_resource(ptr)
        @st1.service_resources.first.update_attributes(:scaling_min => 4)
        expect(ServiceTemplate.count).to eq(1)
        expect(@st1.service_resources.first.scaling_min).to eq(4)
        @st1.template_copy("new_template")
        new_service_template = ServiceTemplate.find_by(:name => "new_template")
        expect(ServiceTemplate.count).to eq(2)
        expect(MiqProvisionRequestTemplate.count).to eq(2)
        expect(new_service_template.guid).not_to eq(@st1.guid)
        expect(new_service_template.display).to be(false)
        expect(new_service_template.service_resources.first.scaling_min).to eq(4)
        expect(@st1.service_resources.first.resource).not_to be(nil)
      end

      it "service template ansible tower with copyable resource" do
        admin = FactoryBot.create(:user_admin)
        vm_template = FactoryBot.create(:vm_openstack, :ext_management_system => FactoryBot.create(:ext_management_system))
        ptr = FactoryBot.create(:miq_provision_request_template, :requester => admin, :src_vm_id => vm_template.id)
        service_template_ansible_tower.add_resource(ptr)
        expect(ServiceTemplate.count).to eq(2)
        service_template_ansible_tower.template_copy("new_template_copy")
        new_service_template = ServiceTemplate.find_by(:name => "new_template_copy")
        expect(ServiceTemplate.count).to eq(3)
        expect(MiqProvisionRequestTemplate.count).to eq(2)
        expect(new_service_template.guid).not_to eq(service_template_ansible_tower.guid)
        expect(new_service_template.display).to be(false)
        expect(new_service_template.service_resources.count).not_to be(0)
        expect(service_template_ansible_tower.service_resources.first.resource).not_to be(nil)
      end

      it "service template orchestration with copyable resource" do
        admin = FactoryBot.create(:user_admin)
        vm_template = FactoryBot.create(:vm_openstack, :ext_management_system => FactoryBot.create(:ext_management_system))
        ptr = FactoryBot.create(:miq_provision_request_template, :requester => admin, :src_vm_id => vm_template.id)
        service_template_orchestration.add_resource(ptr)
        expect(ServiceTemplate.count).to eq(2)
        service_template_orchestration.template_copy("new_template")
        new_service_template = ServiceTemplate.find_by(:name => "new_template")
        expect(ServiceTemplate.count).to eq(3)
        expect(MiqProvisionRequestTemplate.count).to eq(2)
        expect(new_service_template.guid).not_to eq(service_template_orchestration.guid)
        expect(new_service_template.display).to be(false)
        expect(new_service_template.service_resources.count).not_to be(0)
        expect(service_template_orchestration.service_resources.first.resource).not_to be(nil)
      end
    end

    context "without given name" do
      it "without resource" do
        expect(ServiceTemplate.count).to eq(1)
        @st1.template_copy
        new_service_template = ServiceTemplate.find_by("name ILIKE ?", "Copy of service%")
        expect(ServiceTemplate.count).to eq(2)
        expect(new_service_template.guid).not_to eq(@st1.guid)
        expect(new_service_template.display).to be(false)
        expect(new_service_template.service_resources.count).to eq(0)
        expect(@st1.service_resources.count).to eq(0)
      end

      it "with non-copyable resource (configuration_script_base)" do
        @st1.add_resource(FactoryBot.create(:configuration_script_base))
        expect(ServiceTemplate.count).to eq(1)
        @st1.template_copy
        new_service_template = ServiceTemplate.find_by("name ILIKE ?", "Copy of service%")
        expect(ServiceTemplate.count).to eq(2)
        expect(new_service_template.service_resources.first.resource_id).to eq(@st1.service_resources.first.resource_id)
        expect(ConfigurationScriptBase.count).to eq(1)
        expect(new_service_template.display).to be(false)
        expect(new_service_template.guid).not_to eq(@st1.guid)
      end

      it "with non-copyable resource (ext management system)" do
        @st1.add_resource(FactoryBot.create(:ext_management_system))
        expect(ServiceTemplate.count).to eq(1)
        @st1.template_copy
        new_service_template = ServiceTemplate.find_by("name ILIKE ?", "Copy of service%")
        expect(ServiceTemplate.count).to eq(2)
        expect(ServiceTemplate.where("name ILIKE ?", "Copy of service%").first.service_resources.first.resource_id).to eq(@st1.service_resources.first.resource_id)
        expect(ExtManagementSystem.count).to eq(1)
        expect(new_service_template.guid).not_to eq(@st1.guid)
        expect(new_service_template.display).to be(false)
        expect(new_service_template.service_resources.count).not_to be(0)
        expect(@st1.service_resources.first.resource).not_to be(nil)
      end

      it "with non-copyable resource (orchestration template)" do
        @st1.add_resource(FactoryBot.create(:orchestration_template))
        expect(ServiceTemplate.count).to eq(1)
        @st1.template_copy
        new_service_template = ServiceTemplate.find_by("name ILIKE ?", "Copy of service%")
        expect(ServiceTemplate.count).to eq(2)
        expect(ServiceTemplate.where("name ILIKE ?", "Copy of service%").first.service_resources.first.resource_id).to eq(@st1.service_resources.first.resource_id)
        expect(OrchestrationTemplate.count).to eq(1)
        expect(new_service_template.guid).not_to eq(@st1.guid)
        expect(new_service_template.display).to be(false)
        expect(new_service_template.service_resources.count).not_to be(0)
        expect(@st1.service_resources.first.resource).not_to be(nil)
      end

      it "with copyable resource" do
        admin = FactoryBot.create(:user_admin)
        vm_template = FactoryBot.create(:vm_openstack, :ext_management_system => FactoryBot.create(:ext_management_system))
        ptr = FactoryBot.create(:miq_provision_request_template, :requester => admin, :src_vm_id => vm_template.id)
        @st1.add_resource(ptr)
        expect(ServiceTemplate.count).to eq(1)
        @st1.template_copy
        new_service_template = ServiceTemplate.find_by("name ILIKE ?", "Copy of service%")
        expect(ServiceTemplate.count).to eq(2)
        expect(MiqProvisionRequestTemplate.count).to eq(2)
        expect(new_service_template.guid).not_to eq(@st1.guid)
        expect(new_service_template.display).to be(false)
        expect(new_service_template.service_resources.count).not_to be(0)
        expect(@st1.service_resources.first.resource).not_to be(nil)
      end
    end

    context "picture" do
      it "creates a duplicate picture" do
        @st1.picture = { :content => 'foobar', :extension => 'jpg' }
        new_template = @st1.template_copy

        expect(@st1.picture.id).to_not eq(new_template.picture.id)
        expect(@st1.picture.content).to eq(new_template.picture.content)
      end

      it "leave picture nil when source template is nil" do
        new_template = @st1.template_copy

        expect(@st1.picture).to be_nil
        expect(new_template.picture).to be_nil
      end
    end

    context "resource_actions" do
      it "duplicates resource_actions" do
        @st1.resource_actions << [
          FactoryBot.create(:resource_action, :action => "Provision"),
          FactoryBot.create(:resource_action, :action => "Retire")
        ]

        new_template = @st1.template_copy
        expect(new_template.resource_actions.pluck(:action)).to match_array(%w[Provision Retire])
      end
    end

    context "additional tenants" do
      it "duplicates additional tenants" do
        @st1.additional_tenants << [
          FactoryBot.create(:tenant),
          FactoryBot.create(:tenant, :subdomain => nil)
        ]
        expect(@st1.additional_tenants.count).to eq(2)
        new_template = @st1.template_copy
        expect(new_template.additional_tenants.count).to eq(2)
      end
    end
  end
end
