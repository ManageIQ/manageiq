describe ServiceTemplate do
  include_examples "OwnershipMixin"

  describe "#custom_actions" do
    let(:service_template) do
      described_class.create(:name => "test", :description => "test", :custom_button_sets => [assigned_group_set])
    end
    let(:generic_no_group) { FactoryGirl.create(:custom_button, :applies_to_class => "Service") }
    let(:assigned_no_group) { FactoryGirl.create(:custom_button, :applies_to_class => "ServiceTemplate") }
    let(:generic_group) { FactoryGirl.create(:custom_button, :applies_to_class => "Service") }
    let(:assigned_group) { FactoryGirl.create(:custom_button, :applies_to_class => "ServiceTemplate") }
    let(:assigned_group_set) do
      FactoryGirl.create(:custom_button_set, :name => "assigned_group", :description => "assigned_group")
    end
    let(:generic_group_set) do
      FactoryGirl.create(:custom_button_set, :name => "generic_group", :description => "generic_group")
    end

    before do
      allow(generic_no_group).to receive(:expanded_serializable_hash).and_return("generic_no_group")
      allow(assigned_no_group).to receive(:expanded_serializable_hash).and_return("assigned_no_group")

      generic_group_set.add_member(generic_group)
      assigned_group_set.add_member(assigned_group)

      allow(CustomButton).to receive(:buttons_for).with("Service").and_return(
        [generic_no_group, generic_group]
      )
      allow(CustomButton).to receive(:buttons_for).with(service_template).and_return(
        [assigned_no_group, assigned_group]
      )
    end

    it "returns the custom actions in a hash grouped by buttons and button groups" do
      assigned_group_buttons = assigned_group.expanded_serializable_hash.reject do |key, _|
        %w(created_on updated_on).include?(key)
      end
      expected_assigned_group_set = assigned_group_set.serializable_hash.reject { |key, _|
        %w(created_on updated_on).include?(key)
      }.merge(:buttons => [assigned_group_buttons])

      generic_group_buttons = generic_group.expanded_serializable_hash.reject do |key, _|
        %w(created_on updated_on).include?(key)
      end
      expected_generic_group_set = generic_group_set.serializable_hash.reject { |key, _|
        %w(created_on updated_on).include?(key)
      }.merge(:buttons => [generic_group_buttons])

      expected_hash_without_created_or_updated = service_template.custom_actions
      expected_hash_without_created_or_updated[:button_groups].each do |button_group|
        button_group.reject! do |key, _|
          %w(created_on updated_on).include?(key)
        end
        button_group[:buttons].each do |button|
          button.reject! { |key, _| %w(created_on updated_on).include?(key) }
        end
      end

      expect(expected_hash_without_created_or_updated).to eq(
        :buttons       => %w(generic_no_group assigned_no_group),
        :button_groups => [expected_assigned_group_set, expected_generic_group_set]
      )
    end
  end

  context "#type_display" do
    before(:each) do
      @st1 = FactoryGirl.create(:service_template, :name => 'Service Template 1')
    end

    it "with service_type of unknown" do
      expect(@st1.type_display).to eq('Unknown')
    end

    it "with service_type of atomic" do
      @st1.update_attributes(:service_type => 'atomic')
      expect(@st1.type_display).to eq('Item')
    end

    it "with service_type of composite" do
      @st1.update_attributes(:service_type => 'composite')
      expect(@st1.type_display).to eq('Bundle')
    end
  end

  context "#atomic?" do
    before(:each) do
      @st1 = FactoryGirl.create(:service_template)
    end

    it "with service_type of unknown" do
      expect(@st1.atomic?).to be_falsey
    end

    it "with service_type of atomic" do
      @st1.update_attributes(:service_type => 'atomic')
      expect(@st1.atomic?).to be_truthy
    end
  end

  context "#composite?" do
    before(:each) do
      @st1 = FactoryGirl.create(:service_template)
    end

    it "with service_type of unknown" do
      expect(@st1.composite?).to be_falsey
    end

    it "with service_type of composite" do
      @st1.update_attributes(:service_type => 'composite')
      expect(@st1.composite?).to be_truthy
    end
  end

  context "with multiple services" do
    before(:each) do
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
      sub_svc = instance_double("service_task", :options => {:dialog => {}})
      parent_svc = instance_double("service_task", :options => {:dialog => {}})
      expect(parent_svc).to receive(:add_resource!).once

      @svc_a.create_service(sub_svc, parent_svc)
    end

    it "should not call add_resource! if no parent_svc exists" do
      sub_svc = instance_double("service_task", :options => {:dialog => {}})
      expect(sub_svc).to receive(:add_resource!).never

      @svc_a.create_service(sub_svc)
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

      # Print tree-view of services
      # puts "\n#{svc_a.name}"
      # print_svc(svc_a, "  ")
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
    before(:each) do
      @zone1 = FactoryGirl.create(:small_environment)
      allow(MiqServer).to receive(:my_server).and_return(@zone1.miq_servers.first)
      @st1 = FactoryGirl.create(:service_template, :name => 'Service Template 1')
    end

    it "should create a valid service template" do
      expect(@st1.guid).not_to be_empty
      expect(@st1.service_resources.size).to eq(0)
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
      @test_service.reload
      expect(@test_service.evm_owner.name).to eq(@user.name)
      expect(@test_service.evm_owner.current_group).not_to be_nil
      expect(@test_service.evm_owner.current_group.description).to eq(@user.current_group.description)
    end

    it "should create an empty service template without a type" do
      expect(@st1.service_type).to eq('unknown')
      expect(@st1.composite?).to be_falsey
      expect(@st1.atomic?).to be_falsey
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
      before(:each) do
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

      user         = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred')
      @vm_template = FactoryGirl.create(:template_vmware, :ext_management_system => FactoryGirl.create(:ems_vmware_with_authentication))
      @ptr = FactoryGirl.create(:miq_provision_request_template, :requester => user, :src_vm_id => @vm_template.id)
    end

    it 'unknown' do
      expect(@st1.service_type).to eq "unknown"
      expect(@st1.template_valid?).to be_truthy
      expect(@st1.template_valid_error_message).to be_nil
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

  describe '#create_catalog_item' do
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
