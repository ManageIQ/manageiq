require "spec_helper"

describe ManageIQ::Providers::Amazon::CloudManager::ProvisionWorkflow do
  include WorkflowSpecHelper

  let(:admin) { FactoryGirl.create(:user_with_group) }
  let(:ems) { FactoryGirl.create(:ems_amazon) }
  let(:template) { FactoryGirl.create(:template_amazon, :name => "template", :ext_management_system => ems) }
  let(:workflow) do
    stub_dialog
    ManageIQ::Providers::CloudManager::ProvisionWorkflow.any_instance.stub(:update_field_visibility)
    wf = described_class.new({:src_vm_id => template.id}, admin.userid)
    wf.instance_variable_set("@ems_xml_nodes", {})
    wf
  end

  it "pass platform attributes to automate" do
    stub_dialog
    assert_automate_dialog_lookup('cloud', 'amazon')

    described_class.new({}, admin.userid)
  end

  context "with empty relationships" do
    it "#allowed_availability_zones" do
      workflow.allowed_availability_zones.should == {}
    end

    it "#allowed_guest_access_key_pairs" do
      workflow.allowed_guest_access_key_pairs.should == {}
    end

    it "#allowed_security_groups" do
      workflow.allowed_security_groups.should == {}
    end
  end

  context "with valid relationships" do
    it "#allowed_availability_zones" do
      az = FactoryGirl.create(:availability_zone_amazon)
      ems.availability_zones << az
      workflow.allowed_availability_zones.should == {az.id => az.name}
    end

    it "#allowed_guest_access_key_pairs" do
      kp = AuthPrivateKey.create(:name => "auth_1")
      ems.key_pairs << kp
      workflow.allowed_guest_access_key_pairs.should == {kp.id => kp.name}
    end

    it "#allowed_security_groups" do
      sg = FactoryGirl.create(:security_group_amazon, :name => "sq_1")
      ems.security_groups << sg
      workflow.allowed_security_groups.should == {sg.id => sg.name}
    end
  end

  context "when a template object is returned from the provider" do
    context "with empty relationships" do
      it "#allowed_instance_types" do
        workflow.allowed_instance_types.should == {}
      end
    end

    context "with valid relationships" do
      before do
        ems.flavors << FactoryGirl.create(:flavor, :name => "t1.micro",    :supports_32_bit => true,  :supports_64_bit => true)
        ems.flavors << FactoryGirl.create(:flavor, :name => "m1.large",    :supports_32_bit => false, :supports_64_bit => true)
      end

      it "#allowed_instance_types with 32-bit image" do
        template.hardware = FactoryGirl.create(:hardware, :bitness => 32)
        workflow.allowed_instance_types.length.should == 1
      end

      it "#allowed_instance_types with 64-bit image" do
        template.hardware = FactoryGirl.create(:hardware, :bitness => 64)
        workflow.allowed_instance_types.length.should == 2
      end
    end
  end

  context "with VPC relationships" do
    before do
      @az1 = FactoryGirl.create(:availability_zone_amazon, :ext_management_system => ems)
      @az2 = FactoryGirl.create(:availability_zone_amazon, :ext_management_system => ems)
      @az3 = FactoryGirl.create(:availability_zone_amazon, :ext_management_system => ems)

      @cn1 = FactoryGirl.create(:cloud_network, :ext_management_system => ems)

      @cs1 = FactoryGirl.create(:cloud_subnet, :cloud_network => @cn1, :availability_zone => @az1)
      @cs2 = FactoryGirl.create(:cloud_subnet, :cloud_network => @cn1, :availability_zone => @az2)

      @ip1 = FactoryGirl.create(:floating_ip, :cloud_network_only => true,  :ext_management_system => ems)
      @ip2 = FactoryGirl.create(:floating_ip, :cloud_network_only => false, :ext_management_system => ems)

      @sg1 = FactoryGirl.create(:security_group_amazon, :name => "sq_1", :ext_management_system => ems, :cloud_network => @cn1)
      @sg2 = FactoryGirl.create(:security_group_amazon, :name => "sq_1", :ext_management_system => ems)
    end

    it "#allowed_cloud_networks" do
      workflow.allowed_cloud_networks.length.should == 1
    end

    context "#allowed_availability_zones" do
      it "with no placement options" do
        workflow.allowed_availability_zones.should == {
          @az1.id => @az1.name,
          @az2.id => @az2.name,
          @az3.id => @az3.name
        }
      end

      it "with a cloud_network" do
        workflow.values[:cloud_network] = [@cn1.id, @cn1.name]
        workflow.allowed_availability_zones.should == {
          @az1.id => @az1.name,
          @az2.id => @az2.name
        }
      end

      it "with a cloud_network and cloud_subnet" do
        workflow.values[:cloud_network] = [@cn1.id, @cn1.name]
        workflow.values[:cloud_subnet]  = [@cs2.id, @cs2.name]
        workflow.allowed_availability_zones.should == {@az2.id => @az2.name}
      end
    end

    context "#allowed_cloud_subnets" do
      it "without a cloud_network" do
        workflow.allowed_cloud_subnets.length.should be_zero
      end

      it "with a cloud_network" do
        workflow.values[:cloud_network] = [@cn1.id, @cn1.name]
        workflow.allowed_cloud_subnets.length.should == 2
      end

      it "with an cloud_network and Availability Zone" do
        workflow.values[:cloud_network]               = [@cn1.id, @cn1.name]
        workflow.values[:placement_availability_zone] = [@az1.id, @az1.name]

        workflow.allowed_cloud_subnets.length.should == 1
      end
    end

    context "#allowed_floating_ip_addresses" do
      it "without a cloud_network" do
        workflow.allowed_floating_ip_addresses.should == {@ip2.id => @ip2.address}
      end

      it "with a cloud_network" do
        workflow.values[:cloud_network] = [@cn1.id, @cn1.name]
        workflow.allowed_floating_ip_addresses.should == {@ip1.id => @ip1.address}
      end
    end

    context "#allowed_security_groups" do
      it "without a cloud_network" do
        workflow.allowed_security_groups.should == {@sg2.id => @sg2.name}
      end

      it "with a cloud_network" do
        workflow.values[:cloud_network] = [@cn1.id, @cn1.name]
        workflow.allowed_security_groups.should == {@sg1.id => @sg1.name}
      end
    end
  end

  context "#display_name_for_name_description" do
    let(:flavor) { FactoryGirl.create(:flavor_amazon, :name => "test_flavor") }

    it "with name only" do
      workflow.display_name_for_name_description(flavor).should == "test_flavor"
    end

    it "with name and description" do
      flavor.description = "Small"
      workflow.display_name_for_name_description(flavor).should == "test_flavor: Small"
    end
  end

  context "with virtualization type" do
    before do
      @instance_types_32 = ['t2.micro']
      @instance_types_64 = ['m1.medium', 'm1.large']
      ems.flavors << FactoryGirl.create(:flavor_amazon,
                                        :name                 => "t2.micro",
                                        :supports_32_bit      => true,
                                        :supports_64_bit      => true,
                                        :supports_paravirtual => false,
                                        :supports_hvm         => true)
      ems.flavors << FactoryGirl.create(:flavor_amazon,
                                        :name                 => "m1.large",
                                        :supports_32_bit      => false,
                                        :supports_64_bit      => true,
                                        :supports_paravirtual => true,
                                        :supports_hvm         => false)
      ems.flavors << FactoryGirl.create(:flavor_amazon,
                                        :name                 => "m1.medium",
                                        :supports_32_bit      => true,
                                        :supports_64_bit      => true,
                                        :supports_paravirtual => true,
                                        :supports_hvm         => false)
    end

    it "#allowed_instance_types with 32-bit and hvm image" do
      template.hardware = FactoryGirl.create(:hardware, :bitness => 32, :virtualization_type => 'hvm')
      workflow.allowed_instance_types.collect { |_, v| v }.should match_array(@instance_types_32)
    end

    it "#allowed_instance_types with 64-bit and pv image" do
      template.hardware = FactoryGirl.create(:hardware, :bitness => 64, :virtualization_type => 'paravirtual')
      workflow.allowed_instance_types.collect { |_, v| v }.should match_array(@instance_types_64)
    end
  end

  context "with root device type" do
    before do
      @instance_types_64 = ['t1.micro', 'm1.large']
      ems.flavors << FactoryGirl.create(:flavor_amazon,
                                        :name                     => "t1.micro",
                                        :supports_32_bit          => true,
                                        :supports_64_bit          => true,
                                        :supports_paravirtual     => true,
                                        :supports_hvm             => false,
                                        :block_storage_based_only => true)
      ems.flavors << FactoryGirl.create(:flavor_amazon,
                                        :name                     => "m1.large",
                                        :supports_32_bit          => false,
                                        :supports_64_bit          => true,
                                        :supports_paravirtual     => true,
                                        :supports_hvm             => false,
                                        :block_storage_based_only => false)
      ems.flavors << FactoryGirl.create(:flavor_amazon,
                                        :name                     => "t2.medium",
                                        :supports_32_bit          => false,
                                        :supports_64_bit          => true,
                                        :supports_paravirtual     => false,
                                        :supports_hvm             => true,
                                        :block_storage_based_only => true)
    end

    it "#allowed_instance_types with 32-bit, pv and instance_store" do
      template.hardware = FactoryGirl.create(:hardware,
                                             :bitness             => 32,
                                             :virtualization_type => 'paravirtual',
                                             :root_device_type    => 'instance_store')
      workflow.allowed_instance_types.collect { |_, v| v }.should be_empty
    end

    it "#allowed_instance_types with 64-bit, pv and ebs" do
      template.hardware = FactoryGirl.create(:hardware,
                                             :bitness             => 64,
                                             :virtualization_type => 'paravirtual',
                                             :root_device_type    => 'ebs')
      workflow.allowed_instance_types.collect { |_, v| v }.should match_array(@instance_types_64)
    end
  end

  describe "#make_request" do
    let(:alt_user) { FactoryGirl.create(:user_with_group) }
    it "creates and update a request" do
      stub_dialog(:get_pre_dialogs)
      stub_dialog(:get_dialogs)

      # if running_pre_dialog is set, it will run 'continue_request'
      workflow = described_class.new(values = {:running_pre_dialog => false}, admin.userid)

      expect(AuditEvent).to receive(:success).with(
        :event        => "vm_provision_request_created",
        :target_class => "Vm",
        :userid       => admin.userid,
        :message      => "VM Provisioning requested by <#{admin.userid}> for Vm:#{template.id}"
      )

      # creates a request
      stub_get_next_vm_name

      # the dialogs populate this
      values.merge!(:src_vm_id => template.id, :vm_tags => [])

      request = workflow.make_request(nil, values, admin.userid) # TODO: nil

      expect(request).to be_valid
      expect(request).to be_a_kind_of(MiqProvisionRequest)
      expect(request.request_type).to eq("template")
      expect(request.description).to eq("Provision from [#{template.name}] to [New VM]")
      expect(request.requester).to eq(admin)
      expect(request.userid).to eq(admin.userid)
      expect(request.requester_name).to eq(admin.name)

      # updates a request

      stub_get_next_vm_name

      workflow = described_class.new(values, alt_user.userid)

      expect(AuditEvent).to receive(:success).with(
        :event        => "vm_provision_request_updated",
        :target_class => "Vm",
        :userid       => alt_user.userid,
        :message      => "VM Provisioning request updated by <#{alt_user.userid}> for Vm:#{template.id}"
      )
      workflow.make_request(request, values, alt_user.userid)
    end
  end
end
