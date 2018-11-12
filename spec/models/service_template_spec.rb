describe ServiceTemplate do
  include_examples "OwnershipMixin"

  let(:service_user) { FactoryGirl.build(:user) }

  describe "#custom_actions" do
    it "returns the custom actions in a hash grouped by buttons and button groups" do
      FactoryGirl.create(:custom_button, :name => "generic_no_group", :applies_to_class => "Service")
      generic_group = FactoryGirl.create(:custom_button, :name => "generic_group", :applies_to_class => "Service")
      generic_group_set = FactoryGirl.create(:custom_button_set, :name => "generic_group_set")
      generic_group_set.add_member(generic_group)

      service_template = FactoryGirl.create(:service_template)
      FactoryGirl.create(
        :custom_button,
        :name             => "assigned_no_group",
        :applies_to_class => "ServiceTemplate",
        :applies_to_id    => service_template.id
      )
      assigned_group = FactoryGirl.create(
        :custom_button,
        :name             => "assigned_group",
        :applies_to_class => "ServiceTemplate",
        :applies_to_id    => service_template.id
      )
      assigned_group_set = FactoryGirl.create(:custom_button_set, :name => "assigned_group_set")
      assigned_group_set.add_member(assigned_group)
      service_template.update(:custom_button_sets => [assigned_group_set])

      expected = {
        :buttons       => a_collection_containing_exactly(
          a_hash_including("name" => "generic_no_group"),
          a_hash_including("name" => "assigned_no_group")
        ),
        :button_groups => a_collection_containing_exactly(
          a_hash_including(
            "name"   => "assigned_group_set",
            :buttons => [a_hash_including("name" => "assigned_group")]
          ),
          a_hash_including(
            "name"   => "generic_group_set",
            :buttons => [a_hash_including("name" => "generic_group")]
          )
        )
      }
      expect(service_template.custom_actions).to match(expected)
    end

    it "does not show hidden buttons" do
      service_template = FactoryGirl.create(:service_template)
      service = FactoryGirl.create(:service, :name => "foo", :service_template => service_template)
      true_expression = MiqExpression.new("=" => {"field" => "Service-name", "value" => "foo"})
      false_expression = MiqExpression.new("=" => {"field" => "Service-name", "value" => "labar"})
      FactoryGirl.create(:custom_button,
                         :name                  => "visible button",
                         :applies_to_class      => "Service",
                         :visibility_expression => true_expression)
      FactoryGirl.create(:custom_button,
                         :name                  => "hidden button",
                         :applies_to_class      => "Service",
                         :visibility_expression => false_expression)
      FactoryGirl.create(:custom_button_set).tap do |group|
        group.add_member(FactoryGirl.create(:custom_button,
                                            :name                  => "visible button in group",
                                            :applies_to_class      => "Service",
                                            :visibility_expression => true_expression))
        group.add_member(FactoryGirl.create(:custom_button,
                                            :name                  => "hidden button in group",
                                            :applies_to_class      => "Service",
                                            :visibility_expression => false_expression))
      end

      expected = {
        :buttons       => [
          a_hash_including("name" => "visible button")
        ],
        :button_groups => [
          a_hash_including(
            :buttons => [
              a_hash_including("name" => "visible button in group")
            ]
          )
        ]
      }
      expect(service_template.custom_actions(service)).to match(expected)
    end

    context "expression evaluation" do
      let(:service_template) { FactoryGirl.create(:service_template, :prov_type=> "vmware") }
      let(:service) { FactoryGirl.create(:service, :name => "foo", :service_template => service_template) }
      let(:true_expression_on_template) do
        MiqExpression.new("=" => {"field" => "ServiceTemplate-prov_type", "value" => "vmware"})
      end
      let(:false_expression_on_template) do
        MiqExpression.new("=" => {"field" => "ServiceTemplate-prov_type", "value" => "not_vmware"})
      end
      let(:true_expression_on_service) do
        MiqExpression.new("=" => {"field" => "Service-name", "value" => "foo"})
      end
      let(:false_expression_on_service) do
        MiqExpression.new("=" => {"field" => "Service-name", "value" => "not_foo"})
      end

      before do
        FactoryGirl.create(:custom_button,
                           :name                  => "visible button on service",
                           :applies_to_class      => "Service",
                           :visibility_expression => true_expression_on_service)
        FactoryGirl.create(:custom_button,
                           :name                  => "hidden button on service",
                           :applies_to_class      => "Service",
                           :visibility_expression => false_expression_on_service)
        FactoryGirl.create(:custom_button,
                           :name                  => "visible button on template",
                           :applies_to_class      => "ServiceTemplate",
                           :applies_to_id         => service_template.id,
                           :visibility_expression => true_expression_on_template)
        FactoryGirl.create(:custom_button,
                           :name                  => "hidden visible button on template",
                           :applies_to_class      => "ServiceTemplate",
                           :applies_to_id         => service_template.id,
                           :visibility_expression => false_expression_on_template)
      end

      it "uses ServiceTemplate object to evaluate expression defined on Service Template if no parameter passed" do
        expected = {
          :buttons       => [
            a_hash_including("name" => "visible button on template")
          ],
          :button_groups => []
        }
        expect(service_template.custom_actions).to match(expected)
      end

      it "uses passed object for expression defined on that object and ServiceTemplate for expression on template" do
        expected = {
          :buttons       => a_collection_containing_exactly(
            a_hash_including("name" => "visible button on service"),
            a_hash_including("name" => "visible button on template")
          ),
          :button_groups => []
        }
        expect(service_template.custom_actions(service)).to match(expected)
      end
    end

    it "serializes the enablement" do
      service_template = FactoryGirl.create(:service_template, :name => "foo")
      service = FactoryGirl.create(:service, :name => "bar", :service_template => service_template)
      true_expression = MiqExpression.new("=" => {"field" => "Service-name", "value" => "bar"})
      false_expression = MiqExpression.new("=" => {"field" => "Service-name", "value" => "foo"})
      FactoryGirl.create(:custom_button,
                         :name                  => "enabled button",
                         :applies_to_class      => "Service",
                         :enablement_expression => true_expression)
      FactoryGirl.create(:custom_button,
                         :name                  => "disabled button",
                         :applies_to_class      => "Service",
                         :enablement_expression => false_expression)
      FactoryGirl.create(:custom_button_set).tap do |group|
        group.add_member(FactoryGirl.create(:custom_button,
                                            :name                  => "enabled button in group",
                                            :applies_to_class      => "Service",
                                            :enablement_expression => true_expression))
        group.add_member(FactoryGirl.create(:custom_button,
                                            :name                  => "disabled button in group",
                                            :applies_to_class      => "Service",
                                            :enablement_expression => false_expression))
      end

      expected = {
        :buttons       => a_collection_containing_exactly(
          a_hash_including("name" => "enabled button", "enabled" => true),
          a_hash_including("name" => "disabled button", "enabled" => false)
        ),
        :button_groups => [
          a_hash_including(
            :buttons => a_collection_containing_exactly(
              a_hash_including("name" => "enabled button in group", "enabled" => true),
              a_hash_including("name" => "disabled button in group", "enabled" => false)
            )
          )
        ]
      }
      expect(service_template.custom_actions(service)).to match(expected)
    end
  end

  describe "#custom_action_buttons" do
    it "does not show hidden buttons" do
      service_template = FactoryGirl.create(:service_template, :name => "foo")
      true_expression = MiqExpression.new("=" => {"field" => "ServiceTemplate-name", "value" => "foo"})
      false_expression = MiqExpression.new("=" => {"field" => "ServiceTemplate-name", "value" => "bar"})
      visible_button = FactoryGirl.create(:custom_button,
                                          :applies_to_class      => "ServiceTemplate",
                                          :applies_to_id         => service_template.id,
                                          :visibility_expression => true_expression)
      _hidden_button = FactoryGirl.create(:custom_button,
                                          :applies_to_class      => "ServiceTemplate",
                                          :applies_to_id         => service_template.id,
                                          :visibility_expression => false_expression)
      visible_button_in_group = FactoryGirl.create(:custom_button,
                                                   :applies_to_class      => "ServiceTemplate",
                                                   :applies_to_id         => service_template.id,
                                                   :visibility_expression => true_expression)
      hidden_button_in_group = FactoryGirl.create(:custom_button,
                                                  :applies_to_class      => "ServiceTemplate",
                                                  :applies_to_id         => service_template.id,
                                                  :visibility_expression => false_expression)
      service_template.custom_button_sets << FactoryGirl.create(:custom_button_set).tap do |group|
        group.add_member(visible_button_in_group)
        group.add_member(hidden_button_in_group)
      end

      expect(service_template.custom_action_buttons).to contain_exactly(visible_button, visible_button_in_group)
    end
  end

  context "#type_display" do
    before do
      @st1 = FactoryGirl.create(:service_template, :name => 'Service Template 1')
    end

    it "with default service_type" do
      expect(@st1.service_type).to eq("atomic")
      expect(@st1.type_display).to eq('Item')
    end

    it "with service_type of atomic" do
      @st1.update_attributes(:service_type => described_class::SERVICE_TYPE_ATOMIC)
      expect(@st1.type_display).to eq('Item')
    end

    it "with service_type of composite" do
      @st1.update_attributes(:service_type => described_class::SERVICE_TYPE_COMPOSITE)
      expect(@st1.type_display).to eq('Bundle')
    end

    it "with user service_type" do
      @st1.update_attributes(:service_type => 'user')
      expect(@st1.type_display).to eq('User')
    end

    it "with no service_type" do
      @st1.update_attributes(:service_type => nil)
      expect(@st1.type_display).to eq('Unknown')
    end
  end

  context "#atomic?" do
    before do
      @st1 = FactoryGirl.create(:service_template)
    end

    it "with service_type of unknown" do
      @st1.update_attributes(:service_type => 'user')
      expect(@st1.atomic?).to be_falsey
    end

    it "with service_type of atomic" do
      @st1.update_attributes(:service_type => described_class::SERVICE_TYPE_ATOMIC)
      expect(@st1.atomic?).to be_truthy
    end

    it "with service_type of composite" do
      @st1.update_attributes(:service_type => described_class::SERVICE_TYPE_COMPOSITE)
      expect(@st1.atomic?).to be_falsey
    end
  end

  context "#composite?" do
    before do
      @st1 = FactoryGirl.create(:service_template)
    end

    it "with service_type of unknown" do
      @st1.update_attributes(:service_type => 'user')
      expect(@st1.composite?).to be_falsey
    end

    it "with service_type of atomic" do
      @st1.update_attributes(:service_type => described_class::SERVICE_TYPE_ATOMIC)
      expect(@st1.composite?).to be_falsey
    end

    it "with service_type of composite" do
      @st1.update_attributes(:service_type => described_class::SERVICE_TYPE_COMPOSITE)
      expect(@st1.composite?).to be_truthy
    end
  end

  context "initiator" do
    shared_examples_for 'initiator example' do |initiator, match|
      it 'test initiator' do
        svc_template = FactoryGirl.create(:service_template, :name => 'Svc A')
        options = {:dialog => {}}
        options[:initiator] = initiator if initiator
        svc_task = instance_double("service_task", :options => options, :get_user => service_user)
        svc = svc_template.create_service(svc_task, nil)

        expect(svc.initiator).to eq(match)
      end
    end

    context "initiator specified" do
      it_behaves_like 'initiator example', 'fred', 'fred'
    end

    context "initiator not specified" do
      it_behaves_like 'initiator example', nil, 'user'
    end
  end

  context "with multiple services" do
    before do
      @svc_a = FactoryGirl.create(:service_template, :name => 'Svc A')
      @svc_b = FactoryGirl.create(:service_template, :name => 'Svc B')
      @svc_c = FactoryGirl.create(:service_template, :name => 'Svc C')
      @svc_d = FactoryGirl.create(:service_template, :name => 'Svc D')
      @svc_e = FactoryGirl.create(:service_template, :name => 'Svc E')
    end

    it "should return level 1 sub-services" do
      add_and_save_service(@svc_a, @svc_b)
      add_and_save_service(@svc_b, @svc_c)
      add_and_save_service(@svc_a, @svc_c)
      add_and_save_service(@svc_c, @svc_d)

      sub_svc = @svc_a.children
      expect(sub_svc).not_to include(@svc_a)
      expect(sub_svc.size).to eq(2)
      expect(sub_svc).to include(@svc_b)
      expect(sub_svc).to include(@svc_c)
      expect(sub_svc).not_to include(@svc_d)
    end

    it "should return all sub-services" do
      add_and_save_service(@svc_a, @svc_b)
      add_and_save_service(@svc_b, @svc_c)
      add_and_save_service(@svc_a, @svc_c)
      add_and_save_service(@svc_c, @svc_d)

      sub_svc = @svc_a.descendants
      expect(sub_svc.size).to eq(5)
      expect(sub_svc).not_to include(@svc_a)
      expect(sub_svc).to include(@svc_b)
      expect(sub_svc).to include(@svc_c)
      expect(sub_svc).to include(@svc_d)

      sub_svc.uniq!
      expect(sub_svc.size).to eq(3)
      expect(sub_svc).not_to include(@svc_a)
      expect(sub_svc).to include(@svc_b)
      expect(sub_svc).to include(@svc_c)
      expect(sub_svc).to include(@svc_d)
    end

    it "should add_resource! only if a parent_svc exists" do
      sub_svc = instance_double("service_task", :options => {:dialog => {}}, :get_user => service_user)
      parent_svc = instance_double("service_task", :options => {:dialog => {}})
      expect(parent_svc).to receive(:add_resource!).once

      @svc_a.create_service(sub_svc, parent_svc)
    end

    it "should not call add_resource! if no parent_svc exists" do
      sub_svc = instance_double("service_task", :options => {:dialog => {}}, :get_user => service_user)
      expect(sub_svc).to receive(:add_resource!).never

      @svc_a.create_service(sub_svc)
    end

    it "should pass display attribute to created top level service" do
      @svc_a.display = true
      expect(@svc_a.create_service(double(:options => {:dialog => {}}, :get_user => service_user)).display).to eq(true)
    end

    it "should set created child service's display to false" do
      @svc_a.display = true
      allow(@svc_b).to receive(:add_resource!)
      expect(@svc_a.create_service(double(:options => {:dialog => {}}, :get_user => service_user), @svc_b).display).to eq(false)
    end

    it "should set created service's display to false by default" do
      expect(@svc_a.create_service(double(:options => {:dialog => {}}, :get_user => service_user)).display).to eq(false)
    end

    it "should return all parent services for a service" do
      add_and_save_service(@svc_a, @svc_b)
      add_and_save_service(@svc_a, @svc_c)
      add_and_save_service(@svc_a, @svc_d)
      add_and_save_service(@svc_b, @svc_c)

      expect(@svc_a.parent_services).to be_empty

      parents = @svc_b.parent_services
      expect(parents.size).to eq(1)
      expect(parents.first.name).to eq(@svc_a.name)

      parents = @svc_c.parent_services
      expect(parents.size).to eq(2)
      parent_names = parents.collect(&:name)
      expect(parent_names).to include(@svc_a.name)
      expect(parent_names).to include(@svc_b.name)
    end

    it "should not allow service templates to be connected to itself" do
      expect { add_and_save_service(@svc_a, @svc_a) }.to raise_error(MiqException::MiqServiceCircularReferenceError)
    end

    it "should not allow service templates to be connected in a circular reference" do
      expect { add_and_save_service(@svc_a, @svc_b) }.not_to raise_error
      expect { add_and_save_service(@svc_b, @svc_c) }.not_to raise_error
      expect { add_and_save_service(@svc_a, @svc_c) }.not_to raise_error
      expect { add_and_save_service(@svc_c, @svc_d) }.not_to raise_error
      expect { add_and_save_service(@svc_a, @svc_e) }.not_to raise_error

      expect { add_and_save_service(@svc_c, @svc_a) }.to raise_error(MiqException::MiqServiceCircularReferenceError)
      expect { add_and_save_service(@svc_d, @svc_a) }.to raise_error(MiqException::MiqServiceCircularReferenceError)
      expect { add_and_save_service(@svc_c, @svc_b) }.to raise_error(MiqException::MiqServiceCircularReferenceError)
    end

    it "should not allow deeply nested service templates to be connected in a circular reference" do
      expect { add_and_save_service(@svc_a, @svc_b) }.not_to raise_error
      expect { add_and_save_service(@svc_b, @svc_c) }.not_to raise_error

      expect { add_and_save_service(@svc_d, @svc_e) }.not_to raise_error
      expect { add_and_save_service(@svc_e, @svc_a) }.not_to raise_error

      expect { add_and_save_service(@svc_c, @svc_d) }.to raise_error(MiqException::MiqServiceCircularReferenceError)
    end

    it "should not allow service template to connect to self" do
      expect { @svc_a << @svc_a }.to raise_error(MiqException::MiqServiceCircularReferenceError)
    end

    it "should allow service template to connect to a service with the same id" do
      svc = FactoryGirl.create(:service)
      svc.id = @svc_a.id
      expect { svc << @svc_a }.to_not raise_error
    end

    it "should not delete a service that has a parent service" do
      add_and_save_service(@svc_a, @svc_b)
      add_and_save_service(@svc_b, @svc_c)

      expect { @svc_b.destroy }.to raise_error(MiqException::MiqServiceError, /Cannot delete.*child of another service/)
      expect { @svc_c.destroy }.to raise_error(MiqException::MiqServiceError, /Cannot delete.*child of another service/)

      expect { @svc_a.destroy }.not_to raise_error
      expect { @svc_b.destroy }.not_to raise_error
      expect { @svc_c.destroy }.not_to raise_error
    end
  end

  context "with a small env" do
    before do
      @zone1 = FactoryGirl.create(:small_environment)
      allow(MiqServer).to receive(:my_server).and_return(@zone1.miq_servers.first)
      @st1 = FactoryGirl.create(:service_template, :name => 'Service Template 1')
    end

    it "should create a valid service template" do
      expect(@st1.guid).not_to be_empty
      expect(@st1.service_resources.size).to eq(0)
      expect(@st1.service_type).to eq(described_class::SERVICE_TYPE_ATOMIC)
    end

    it "should not set the owner for the service template" do
      @user         = nil
      @test_service = FactoryGirl.create(:service, :name => 'test service')
      expect(@test_service.evm_owner).to be_nil
      @st1.set_ownership(@test_service, @user)
      expect(@test_service.evm_owner).to be_nil
    end

    it "should set the owner and group for the service template" do
      @user         = FactoryGirl.create(:user_with_group)
      @test_service = FactoryGirl.create(:service, :name => 'test service')
      expect(@test_service.evm_owner).to be_nil
      @st1.set_ownership(@test_service, @user)
      expect(@test_service.evm_owner.name).to eq(@user.name)
      expect(@test_service.evm_owner.current_group).not_to be_nil
      expect(@test_service.evm_owner.current_group.description).to eq(@user.current_group.description)
    end

    it "should create a composite service template" do
      st2 = FactoryGirl.create(:service_template, :name => 'Service Template 2')
      @st1.add_resource(st2)
      expect(@st1.service_resources.size).to eq(1)
      expect(@st1.composite?).to be_truthy
      expect(@st1.atomic?).to be_falsey
    end

    it "should create an atomic service template" do
      vm = Vm.first
      @st1.add_resource(vm)
      expect(@st1.service_resources.size).to eq(1)
      expect(@st1.atomic?).to be_truthy
      expect(@st1.composite?).to be_falsey
    end

    context "with a VM Provision Request Template" do
      before do
        admin = FactoryGirl.create(:user_admin)

        vm_template = Vm.first
        ptr = FactoryGirl.create(:miq_provision_request_template, :requester => admin, :src_vm_id => vm_template.id)
        @st1.add_resource(ptr)
      end

      it "should allow VM Provision Request Template as a resource" do
        expect(@st1.service_resources.size).to eq(1)
        expect(@st1.atomic?).to be_truthy
        expect(@st1.composite?).to be_falsey
      end

      it "should delete the VM Provision Request Template when the service template is deleted" do
        expect(ServiceTemplate.count).to eq(1)
        expect(MiqProvisionRequestTemplate.count).to eq(1)
        @st1.destroy
        expect(ServiceTemplate.count).to eq(0)
        expect(MiqProvisionRequestTemplate.count).to eq(0)
      end
    end
  end

  context 'validate template' do
    before do
      @st1 = FactoryGirl.create(:service_template, :name => 'Service Template 1')

      user         = FactoryGirl.create(:user, :name => 'Fred Flintstone', :userid => 'fred')
      @vm_template = FactoryGirl.create(:template_vmware, :ext_management_system => FactoryGirl.create(:ems_vmware_with_authentication))
      @ptr = FactoryGirl.create(:miq_provision_request_template, :requester => user, :src_vm_id => @vm_template.id)
    end

    context 'atomic' do
      before { @st1.add_resource(@ptr) }

      it 'valid template' do
        expect(@st1.template_valid?).to be_truthy
        expect(@st1.template_valid_error_message).to be_nil
      end

      it 'orphaned template' do
        allow_any_instance_of(VmOrTemplate).to receive(:orphaned?).and_return(true)
        expect(@st1.template_valid?).to be_falsey
        expect(@st1.template_valid_error_message).to include("Id <#{@vm_template.id}> is orphaned")
      end

      it 'archived template' do
        allow_any_instance_of(VmOrTemplate).to receive(:archived?).and_return(true)
        expect(@st1.template_valid?).to be_falsey
        expect(@st1.template_valid_error_message).to include("Id <#{@vm_template.id}> is archived")
      end

      it 'not existing template' do
        @ptr.update_attributes(:src_vm_id => 999)
        expect(@st1.template_valid?).to be_falsey
        expect(@st1.template_valid_error_message).to include("Unable to find VM with Id [999]")
      end

      it 'generic' do
        @st1.remove_resource(@ptr)
        expect(@st1.template_valid?).to be_truthy
        expect(@st1.template_valid_error_message).to be_nil
      end

      it 'not existing request' do
        @st1.save!
        @ptr.destroy
        expect(@st1.reload.template_valid?).to be_falsey
        msg = "Missing Service Resource(s): #{@ptr.class.base_model.name}:#{@ptr.id}"
        expect(@st1.template_valid_error_message).to include(msg)
      end
    end

    context 'composite' do
      before do
        @st1.add_resource(@ptr)
        @st2 = FactoryGirl.create(:service_template, :name => 'Service Template 2')
        @st2.add_resource(@st1)
      end

      it 'valid template' do
        expect(@st2.template_valid?).to be_truthy
        expect(@st2.template_valid_error_message).to be_nil
      end

      it 'orphaned template' do
        allow_any_instance_of(VmOrTemplate).to receive(:orphaned?).and_return(true)
        expect(@st2.template_valid?).to be_falsey
        expect(@st2.template_valid_error_message).to include("Id <#{@vm_template.id}> is orphaned")
      end

      it 'archived template' do
        allow_any_instance_of(VmOrTemplate).to receive(:archived?).and_return(true)
        expect(@st2.template_valid?).to be_falsey
        expect(@st2.template_valid_error_message).to include("Id <#{@vm_template.id}> is archived")
      end

      it 'not existing template' do
        @ptr.update_attributes(:src_vm_id => 999)
        expect(@st2.template_valid?).to be_falsey
        expect(@st2.template_valid_error_message).to include("Unable to find VM with Id [999]")
      end
    end
  end

  describe 'generic_subtype' do
    context 'when prov_type = generic ' do
      it 'sets a default value' do
        st = ServiceTemplate.create(:prov_type => 'generic')
        expect(st.generic_subtype).to eq('custom')
      end

      it 'sets specified value' do
        st = ServiceTemplate.create(:prov_type => 'generic', :generic_subtype => 'vm')
        expect(st.generic_subtype).to eq('vm')
      end
    end

    context 'when prov_type != generic' do
      it 'does not set default value' do
        st = ServiceTemplate.create(:prov_type => 'vmware')
        expect(st.generic_subtype).to be_nil
      end
    end
  end

  describe "#provision_action" do
    it "returns the provision action" do
      provision_action = FactoryGirl.create(:resource_action, :action => "Provision")
      service_template = FactoryGirl.create(:service_template, :resource_actions => [provision_action])
      expect(service_template.provision_action).to eq(provision_action)
    end
  end

  describe '#config_info' do
    before do
      @user = FactoryGirl.create(:user_with_group)
      @ra = FactoryGirl.create(:resource_action, :action => 'Provision', :fqname => '/a/b/c')
    end

    it 'returns the config_info passed to #create_catalog_item' do
      options = {
        :name        => 'foo',
        :config_info => {
          :provision  => {
            :fqname => @ra.fqname
          },
          :retirement => {
            :fqname => @ra.fqname
          }
        }
      }

      template = ServiceTemplate.create_catalog_item(options, @user)
      expect(template.config_info).to eq(options[:config_info])
    end

    it 'will build the config_info if not created through #create_catalog_item' do
      dialog = FactoryGirl.create(:dialog)
      template = FactoryGirl.create(:service_template)
      request = FactoryGirl.create(:service_template_provision_request,
                                   :requester => @user,
                                   :options   => {:foo => 'bar', :baz => nil })
      template.create_resource_actions(:provision => { :fqname => @ra.fqname, :dialog_id => dialog.id })
      add_and_save_service(template, request)
      template.reload

      expected_config_info = {
        :foo       => 'bar',
        :provision => {
          :fqname    => '/a/b/c',
          :dialog_id => dialog.id
        }
      }
      expect(template.config_info).to eq(expected_config_info)
    end
  end

  describe '.class_from_request_data' do
    it 'returns the correct generic type' do
      template_class = ServiceTemplate.class_from_request_data('prov_type' => 'generic_ansible_tower')

      expect(template_class).to eq(ServiceTemplateAnsibleTower)
    end

    it 'returns the correct non generic type' do
      template_class = ServiceTemplate.class_from_request_data('prov_type' => 'amazon')

      expect(template_class).to eq(ServiceTemplate)
    end
  end

  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:ra1) { FactoryGirl.create(:resource_action, :action => 'Provision') }
  let(:ra2) { FactoryGirl.create(:resource_action, :action => 'Retirement') }
  let(:ems) { FactoryGirl.create(:ems_amazon) }
  let(:vm) { FactoryGirl.create(:vm_amazon, :ext_management_system => ems) }
  let(:flavor) { FactoryGirl.create(:flavor_amazon) }
  let(:request_dialog) { FactoryGirl.create(:miq_dialog_provision) }
  let(:service_dialog) { FactoryGirl.create(:dialog) }
  let(:catalog_item_options) do
    {
      :name         => 'Atomic Service Template',
      :service_type => 'atomic',
      :prov_type    => 'amazon',
      :display      => 'false',
      :description  => 'a description',
      :config_info  => {
        :miq_request_dialog_name => request_dialog.name,
        :placement_auto          => [true, 1],
        :number_of_vms           => [1, '1'],
        :src_vm_id               => [vm.id, vm.name],
        :vm_name                 => vm.name,
        :schedule_type           => ['immediately', 'Immediately on Approval'],
        :instance_type           => [flavor.id, flavor.name],
        :src_ems_id              => [ems.id, ems.name],
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

  describe '.create_catalog_item' do
    it 'creates and returns a catalog item' do
      service_template = ServiceTemplate.create_catalog_item(catalog_item_options, user)

      expect(service_template.name).to eq('Atomic Service Template')
      expect(service_template.service_resources.count).to eq(1)
      expect(service_template.service_resources.first.resource_type).to eq('MiqRequest')
      expect(service_template.dialogs.first).to eq(service_dialog)
      expect(service_template.resource_actions.pluck(:action)).to include('Provision', 'Retirement')
      expect(service_template.resource_actions.pluck(:ae_attributes)).to include({:service_action=>"Provision"}, {:service_action=>"Retirement"})
      expect(service_template.resource_actions.first.dialog).to eq(service_dialog)
      expect(service_template.resource_actions.last.dialog).to eq(service_dialog)
      expect(service_template.config_info).to eq(catalog_item_options[:config_info])
    end
  end

  describe '#update_catalog_item' do
    let(:new_vm) { FactoryGirl.create(:vm_amazon, :ext_management_system => ems) }
    let(:updated_catalog_item_options) do
      {
        :name        => 'Updated Template Name',
        :display     => 'false',
        :description => 'a description',
        :config_info => {
          :miq_request_dialog_name => request_dialog.name,
          :placement_auto          => [true, 1],
          :number_of_vms           => [1, '1'],
          :src_vm_id               => [new_vm.id, new_vm.name],
          :vm_name                 => new_vm.name,
          :schedule_type           => ['immediately', 'Immediately on Approval'],
          :instance_type           => [flavor.id, flavor.name],
          :src_ems_id              => [ems.id, ems.name],
          :provision               => {
            :fqname    => 'a1/b1/c1',
            :dialog_id => nil
          },
          :reconfigure             => {
            :fqname    => 'x1/y1/z1',
            :dialog_id => service_dialog.id
          }
        }
      }
    end

    before do
      @catalog_item = ServiceTemplate.create_catalog_item(catalog_item_options, user)
      @catalog_item.update_attributes!(:options => @catalog_item.options.merge(:foo => 'bar'))
    end

    it 'updates the catalog item' do
      updated = @catalog_item.update_catalog_item(updated_catalog_item_options, user)

      # Removes Retirement / Adds Reconfigure
      expect(updated.resource_actions.pluck(:action)).to match_array(%w(Provision Reconfigure))
      expect(updated.resource_actions.first.dialog_id).to be_nil # Removes the dialog from Provision
      expect(updated.resource_actions.first.fqname).to eq('/a1/b1/c1')
      expect(updated.resource_actions.last.dialog).to eq(service_dialog)
      expect(updated.resource_actions.last.fqname).to eq('/x1/y1/z1')
      expect(updated.name).to eq('Updated Template Name')
      expect(updated.service_resources.first.resource.source_id).to eq(new_vm.id) # Validate request update
      expect(updated.config_info).to eq(updated_catalog_item_options[:config_info])
      expect(updated.options.key?(:foo)).to be_truthy # Test that the options were merged
    end

    it 'does not allow service_type to be changed' do
      expect do
        @catalog_item.update_catalog_item({:service_type => 'new'}, user)
      end.to raise_error(StandardError, /service_type cannot be changed/)
    end

    it 'does not allow prov_type to be changed' do
      expect do
        @catalog_item.update_catalog_item({:prov_type => 'new'}, user)
      end.to raise_error(StandardError, /prov_type cannot be changed/)
    end

    it 'accepts prov_type and service_type if they are not changed' do
      expect do
        @catalog_item.update_catalog_item({:name         => 'new_name',
                                           :service_type => @catalog_item.service_type,
                                           :prov_type    => @catalog_item.prov_type}, user)
      end.to change(@catalog_item, :name)
      expect(@catalog_item.reload.name).to eq('new_name')
    end

    it 'allows for update without the presence of config_info' do
      expect do
        @catalog_item.update_catalog_item(:name => 'new_name')
      end.to change(@catalog_item, :name)
      expect(@catalog_item.reload.name).to eq('new_name')
    end
  end

  context "#order" do
    let(:user) { FactoryGirl.create(:user, :userid => "barney") }
    let(:resource_action) { FactoryGirl.create(:resource_action, :action => "Provision") }
    let(:service_template) { FactoryGirl.create(:service_template, :resource_actions => [resource_action]) }
    let(:resource_action_options) { {:target => service_template, :initiator => 'control', :submit_workflow => true} }
    let(:miq_request) { FactoryGirl.create(:service_template_provision_request) }
    let!(:resource_action_workflow) { ResourceActionWorkflow.new({}, user, resource_action, resource_action_options) }

    before do
      allow(ResourceActionWorkflow).to(receive(:new).and_return(resource_action_workflow))
    end

    it "success no optional args" do
      expect(resource_action_workflow).to receive(:submit_request).and_return(miq_request)

      expect(service_template.order(user)).to eq(miq_request)
    end

    it "successfully scheduled" do
      EvmSpecHelper.local_miq_server
      expect(resource_action_workflow).to receive(:validate_dialog).and_return([])

      time   = Time.zone.now.utc.to_s
      result = service_template.order(user, {}, {}, time)

      expect(result.keys).to eq([:schedule]) # No errors
      expect(result[:schedule]).to have_attributes(
        :name         => "Order ServiceTemplate #{service_template.id} at #{time}",
        :sched_action => {:args => [user.id, {}, {}], :method => "queue_order"},
        :resource     => service_template
      )
    end

    it "#queue_order" do
      EvmSpecHelper.local_miq_server

      service_template.queue_order(user.id, {}, {})

      expect(MiqQueue.first).to have_attributes(
        :args        => [user.id, {}, {}],
        :class_name  => "ServiceTemplate",
        :instance_id => service_template.id,
        :method_name => "order",
      )
    end

    it "successfully scheduled twice" do
      EvmSpecHelper.local_miq_server
      expect(resource_action_workflow).to receive(:validate_dialog).twice.and_return([])

      service_template.order(user, {}, {}, Time.zone.now.utc.to_s)
      service_template.order(user, {}, {}, (Time.zone.now + 1.hour).utc.to_s)

      expect(service_template.miq_schedules.length).to eq(2)
    end

    context "#provision_request" do
      let(:arg1) { {'ordered_by' => 'fred'} }

      context "with init_defaults" do
        let(:arg2) { {:init_defaults => true} }

        it "provisions a service template without errors" do
          expect(resource_action_workflow).to receive(:validate_dialog).and_return([])
          expect(resource_action_workflow).to receive(:make_request).and_return(miq_request)
          expect(resource_action_workflow).to receive(:request_options=).with(
            :init_defaults => true, :provision_workflow => true
          )

          expect(service_template.provision_request(user, arg1, arg2)).to eq(miq_request)
        end

        it "provisions a service template with errors" do
          expect(resource_action_workflow).to receive(:validate_dialog).and_return(%w(Error1 Error2))
          expect(resource_action_workflow).to receive(:request_options=).with(
            :init_defaults => true, :provision_workflow => true
          )

          expect { service_template.provision_request(user, arg1, arg2) }.to raise_error(RuntimeError)
        end
      end

      context "with submit_workflow" do
        let(:arg2) { {:initiator => 'control', :submit_workflow => true} }

        it "provisions a service template without errors" do
          expect(resource_action_workflow).to receive(:validate_dialog).and_return([])
          expect(resource_action_workflow).to receive(:make_request).and_return(miq_request)
          expect(resource_action_workflow).to receive(:request_options=).with(
            :initiator => 'control', :submit_workflow => true
          )

          expect(service_template.provision_request(user, arg1, arg2)).to eq(miq_request)
        end

        it "provisions a service template with errors" do
          expect(resource_action_workflow).to receive(:validate_dialog).and_return(%w(Error1 Error2))
          expect(resource_action_workflow).to receive(:request_options=).with(
            :initiator => 'control', :submit_workflow => true
          )

          expect { service_template.provision_request(user, arg1, arg2) }.to raise_error(RuntimeError)
        end
      end

      context "without submit_workflow" do
        let(:arg2) { {:initiator => 'control'} }

        it "provisions a service template without errors" do
          expect(resource_action_workflow).to receive(:validate_dialog).and_return([])
          expect(resource_action_workflow).to receive(:make_request).and_return(miq_request)
          expect(resource_action_workflow).to receive(:request_options=).with(
            :initiator => 'control', :provision_workflow => true
          )

          expect(service_template.provision_request(user, arg1, arg2)).to eq(miq_request)
        end

        it "provisions a service template with errors" do
          expect(resource_action_workflow).to receive(:validate_dialog).and_return(%w(Error1 Error2))
          expect(resource_action_workflow).to receive(:request_options=).with(
            :initiator => 'control', :provision_workflow => true
          )

          expect { service_template.provision_request(user, arg1, arg2) }.to raise_error(RuntimeError)
        end
      end

      context "without any request options" do
        it "provisions a service template without errors" do
          expect(resource_action_workflow).to receive(:validate_dialog).and_return([])
          expect(resource_action_workflow).to receive(:make_request).and_return(miq_request)
          expect(resource_action_workflow).to receive(:request_options=).with(:provision_workflow => true)

          expect(service_template.provision_request(user, arg1)).to eq(miq_request)
        end

        it "provisions a service template with errors" do
          expect(resource_action_workflow).to receive(:validate_dialog).and_return(%w(Error1 Error2))
          expect(resource_action_workflow).to receive(:request_options=).with(:provision_workflow => true)

          expect { service_template.provision_request(user, arg1) }.to raise_error(RuntimeError)
        end
      end
    end
  end

  context "catalog_item_types" do
    it "only returns generic with no providers" do
      expect(ServiceTemplate.catalog_item_types).to match(
        hash_including('amazon'  => {:description => 'Amazon',  :display => false},
                       'generic' => {:description => 'Generic', :display => true })
      )
    end

    it "returns orchestration template and generic" do
      FactoryGirl.create(:orchestration_template)
      expect(ServiceTemplate.catalog_item_types).to match(
        hash_including('amazon'                => { :description => 'Amazon',
                                                    :display     => false },
                       'generic'               => { :description => 'Generic',
                                                    :display     => true },
                       'generic_orchestration' => { :description => 'Orchestration',
                                                    :display     => true})
      )
    end
  end

  context "#archive" do
    let(:service_template) { FactoryGirl.create(:service_template, :miq_requests => miq_requests) }
    context "with no MiqRequests" do
      let(:miq_requests) { [] }

      it "archives the service_template" do
        service_template.archive
        expect(service_template.reload.archived?).to be_truthy
      end
    end

    context "with no active MiqRequests" do
      let(:miq_requests) { [FactoryGirl.create(:service_template_provision_request, :request_state => "finished")] }
      it "archives the service_template" do
        service_template.archive
        expect(service_template.reload.archived?).to be_truthy
      end
    end

    context "with an active MiqRequest" do
      let(:miq_requests) do
        [
          FactoryGirl.create(:service_template_provision_request, :request_state => "finished"),
          FactoryGirl.create(:service_template_provision_request, :request_state => "queued"),
        ]
      end

      it "archives the service_template" do
        expect { service_template.archive }.to raise_error("Cannot archive while in use")
        expect(service_template.reload.archived?).to be_falsy
      end
    end
  end
end

def add_and_save_service(p, c)
  p.add_resource(c)
  p.service_resources.each(&:save)
end

def print_svc(svc, indent = "")
  return if indent.length > 10
  svc.service_resources.each do |s|
    puts indent + s.resource.name
    print_svc(s.resource, indent + "  ")
  end
end
