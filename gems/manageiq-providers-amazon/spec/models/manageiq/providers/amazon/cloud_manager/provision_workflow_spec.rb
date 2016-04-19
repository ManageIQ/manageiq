describe ManageIQ::Providers::Amazon::CloudManager::ProvisionWorkflow do
  include WorkflowSpecHelper

  let(:admin) { FactoryGirl.create(:user_with_group) }
  let(:ems) { FactoryGirl.create(:ems_amazon) }
  let(:template) { FactoryGirl.create(:template_amazon, :name => "template", :ext_management_system => ems) }
  let(:workflow) do
    stub_dialog
    allow_any_instance_of(User).to receive(:get_timezone).and_return(Time.zone)
    allow_any_instance_of(ManageIQ::Providers::CloudManager::ProvisionWorkflow).to receive(:update_field_visibility)
    wf = described_class.new({:src_vm_id => template.id}, admin.userid)
    wf
  end

  it "pass platform attributes to automate" do
    stub_dialog
    assert_automate_dialog_lookup(admin, 'cloud', 'amazon')

    described_class.new({}, admin.userid)
  end

  context "with empty relationships" do
    it "#allowed_availability_zones" do
      expect(workflow.allowed_availability_zones).to eq({})
    end

    it "#allowed_guest_access_key_pairs" do
      expect(workflow.allowed_guest_access_key_pairs).to eq({})
    end

    it "#allowed_security_groups" do
      expect(workflow.allowed_security_groups).to eq({})
    end
  end

  context "with valid relationships" do
    it "#allowed_availability_zones" do
      az = FactoryGirl.create(:availability_zone_amazon)
      ems.availability_zones << az
      expect(workflow.allowed_availability_zones).to eq(az.id => az.name)
    end

    it "#allowed_guest_access_key_pairs" do
      kp = AuthPrivateKey.create(:name => "auth_1")
      ems.key_pairs << kp
      expect(workflow.allowed_guest_access_key_pairs).to eq(kp.id => kp.name)
    end

    it "#allowed_security_groups" do
      sg = FactoryGirl.create(:security_group_amazon, :name => "sq_1")
      ems.network_manager.security_groups << sg
      expect(workflow.allowed_security_groups).to eq(sg.id => sg.name)
    end
  end

  context "without applied tags" do
    context "availability_zones" do
      it "#get_targets_for_ems" do
        az = FactoryGirl.create(:availability_zone_amazon)
        ems.availability_zones << az
        filtered = workflow.send(:get_targets_for_ems, ems, :cloud_filter, AvailabilityZone,
                                 'availability_zones.available')
        expect(filtered.size).to eq(1)
        expect(filtered.first.name).to eq(az.name)
      end

      it "returns an empty array when no targets are found" do
        filtered = workflow.send(:get_targets_for_ems, ems, :cloud_filter, AvailabilityZone,
                                 'availability_zones.available')
        expect(filtered).to eq([])
      end
    end

    context "security_groups" do
      context "non cloud network" do
        it "#get_targets_for_ems" do
          sg = FactoryGirl.create(:security_group_amazon, :name => "sg_1", :ext_management_system => ems)
          ems.security_groups << sg
          filtered = workflow.send(:get_targets_for_ems, ems, :cloud_filter, SecurityGroup,
                                   'security_groups.non_cloud_network')
          expect(filtered.size).to eq(1)
          expect(filtered.first.name).to eq(sg.name)
        end
      end

      context "cloud network" do
        it "#get_targets_for_ems" do
          cn1 = FactoryGirl.create(:cloud_network, :ext_management_system => ems)
          sg_cn = FactoryGirl.create(:security_group_amazon, :name => "sg_2", :ext_management_system => ems,
                                     :cloud_network => cn1)
          ems.security_groups << sg_cn
          filtered = workflow.send(:get_targets_for_ems, ems, :cloud_filter, SecurityGroup, 'security_groups')
          expect(filtered.size).to eq(1)
          expect(filtered.first.name).to eq(sg_cn.name)
        end
      end
    end

    context "Instance Type (Flavor)" do
      it "#get_targets_for_ems" do
        flavor = FactoryGirl.create(:flavor, :name => "t1.micro", :supports_32_bit => true, :supports_64_bit => true)
        ems.flavors << flavor
        filtered = workflow.send(:get_targets_for_ems, ems, :cloud_filter, Flavor, 'flavors')
        expect(filtered.size).to eq(1)
        expect(filtered.first.name).to eq(flavor.name)
      end
    end
  end

  context "with applied tags" do
    before do
      FactoryGirl.create(:classification_cost_center_with_tags)
      admin.current_group.entitlement = Entitlement.create!(:filters => {'managed'   => [['/managed/cc/001']],
                                                                         'belongsto' => []})

      2.times { FactoryGirl.create(:availability_zone_amazon, :ems_id => ems.id) }
      2.times do
        FactoryGirl.create(:security_group_amazon, :name                  => "sgb_1",
                                                   :ext_management_system => ems.network_manager)
      end
      ems.flavors << FactoryGirl.create(:flavor, :name => "t1.micro", :supports_32_bit => true,
                                        :supports_64_bit => true)
      ems.flavors << FactoryGirl.create(:flavor, :name => "m1.large", :supports_32_bit => false,
                                        :supports_64_bit => true)

      tagged_zone = ems.availability_zones.first
      tagged_sec = ems.security_groups.first
      tagged_flavor = ems.flavors.first
      Classification.classify(tagged_zone, 'cc', '001')
      Classification.classify(tagged_sec, 'cc', '001')
      Classification.classify(tagged_flavor, 'cc', '001')
    end

    context "availability_zones" do
      it "#get_targets_for_ems" do
        expect(ems.availability_zones.size).to eq(2)
        expect(ems.availability_zones.first.tags.size).to eq(1)
        expect(ems.availability_zones.last.tags.size).to eq(0)
        filtered = workflow.send(:get_targets_for_ems, ems, :cloud_filter, AvailabilityZone,
                                 'availability_zones.available')
        expect(filtered.size).to eq(1)
      end
    end

    context "security groups" do
      it "#get_targets_for_ems" do
        expect(ems.security_groups.size).to eq(2)
        expect(ems.security_groups.first.tags.size).to eq(1)
        expect(ems.security_groups.last.tags.size).to eq(0)

        filtered = workflow.send(:get_targets_for_ems, ems, :cloud_filter, SecurityGroup, 'security_groups')
        expect(filtered.size).to eq(1)
      end
    end

    context "instance types (Flavor)" do
      it "#get_targets_for_ems" do
        expect(ems.flavors.size).to eq(2)
        expect(ems.flavors.first.tags.size).to eq(1)
        expect(ems.flavors.last.tags.size).to eq(0)

        expect(workflow.send(:get_targets_for_ems, ems, :cloud_filter, Flavor, 'flavors').size).to eq(1)
      end
    end
  end

  context "when a template object is returned from the provider" do
    context "with empty relationships" do
      it "#allowed_instance_types" do
        expect(workflow.allowed_instance_types).to eq({})
      end
    end

    context "with valid relationships" do
      before do
        ems.flavors << FactoryGirl.create(:flavor, :name => "t1.micro", :supports_32_bit => true,
                                          :supports_64_bit => true)
        ems.flavors << FactoryGirl.create(:flavor, :name => "m1.large", :supports_32_bit => false,
                                          :supports_64_bit => true)
      end

      it "#allowed_instance_types with 32-bit image" do
        template.hardware = FactoryGirl.create(:hardware, :bitness => 32)
        expect(workflow.allowed_instance_types.length).to eq(1)
      end

      it "#allowed_instance_types with 64-bit image" do
        template.hardware = FactoryGirl.create(:hardware, :bitness => 64)
        expect(workflow.allowed_instance_types.length).to eq(2)
      end
    end
  end

  context "with VPC relationships" do
    before do
      @az1 = FactoryGirl.create(:availability_zone_amazon, :ext_management_system => ems)
      @az2 = FactoryGirl.create(:availability_zone_amazon, :ext_management_system => ems)
      @az3 = FactoryGirl.create(:availability_zone_amazon, :ext_management_system => ems)

      @cn1 = FactoryGirl.create(:cloud_network, :ext_management_system => ems.network_manager)

      @cs1 = FactoryGirl.create(:cloud_subnet, :cloud_network         => @cn1,
                                               :availability_zone     => @az1,
                                               :ext_management_system => ems.network_manager)
      @cs2 = FactoryGirl.create(:cloud_subnet, :cloud_network         => @cn1,
                                               :availability_zone     => @az2,
                                               :ext_management_system => ems.network_manager)

      @ip1 = FactoryGirl.create(:floating_ip, :cloud_network_only    => true,
                                              :ext_management_system => ems.network_manager)
      @ip2 = FactoryGirl.create(:floating_ip, :cloud_network_only    => false,
                                              :ext_management_system => ems.network_manager)

      @sg1 = FactoryGirl.create(:security_group_amazon, :name                  => "sgn_1",
                                                        :ext_management_system => ems.network_manager,
                                                        :cloud_network         => @cn1)
      @sg2 = FactoryGirl.create(:security_group_amazon, :name => "sgn_2", :ext_management_system => ems.network_manager)
    end

    it "#allowed_cloud_networks" do
      expect(workflow.allowed_cloud_networks.length).to eq(1)
    end

    context "#allowed_availability_zones" do
      it "with no placement options" do
        expect(workflow.allowed_availability_zones).to eq(@az1.id => @az1.name,
                                                          @az2.id => @az2.name,
                                                          @az3.id => @az3.name)
      end

      it "with a cloud_network" do
        workflow.values[:cloud_network] = [@cn1.id, @cn1.name]
        expect(workflow.allowed_availability_zones).to eq(@az1.id => @az1.name,
                                                          @az2.id => @az2.name)
      end

      it "with a cloud_network and cloud_subnet" do
        workflow.values[:cloud_network] = [@cn1.id, @cn1.name]
        workflow.values[:cloud_subnet]  = [@cs2.id, @cs2.name]
        expect(workflow.allowed_availability_zones).to eq(@az2.id => @az2.name)
      end
    end

    context "#allowed_cloud_subnets" do
      it "without a cloud_network" do
        expect(workflow.allowed_cloud_subnets.length).to be_zero
      end

      it "with a cloud_network" do
        workflow.values[:cloud_network] = [@cn1.id, @cn1.name]
        expect(workflow.allowed_cloud_subnets.length).to eq(2)
      end

      it "with an cloud_network and Availability Zone" do
        workflow.values[:cloud_network]               = [@cn1.id, @cn1.name]
        workflow.values[:placement_availability_zone] = [@az1.id, @az1.name]

        expect(workflow.allowed_cloud_subnets.length).to eq(1)
      end
    end

    context "#allowed_floating_ip_addresses" do
      it "without a cloud_network" do
        expect(workflow.allowed_floating_ip_addresses).to eq(@ip2.id => @ip2.address)
      end

      it "with a cloud_network" do
        workflow.values[:cloud_network] = [@cn1.id, @cn1.name]
        expect(workflow.allowed_floating_ip_addresses).to eq(@ip1.id => @ip1.address)
      end
    end

    context "#allowed_security_groups" do
      it "without a cloud_network" do
        expect(workflow.allowed_security_groups).to eq(@sg2.id => @sg2.name)
      end

      it "with a cloud_network" do
        workflow.values[:cloud_network] = [@cn1.id, @cn1.name]
        expect(workflow.allowed_security_groups).to eq(@sg1.id => @sg1.name)
      end
    end
  end

  context "#display_name_for_name_description" do
    let(:flavor) { FactoryGirl.create(:flavor_amazon, :name => "test_flavor") }

    it "with name only" do
      expect(workflow.display_name_for_name_description(flavor)).to eq("test_flavor")
    end

    it "with name and description" do
      flavor.description = "Small"
      expect(workflow.display_name_for_name_description(flavor)).to eq("test_flavor: Small")
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
      expect(workflow.allowed_instance_types.collect { |_, v| v }).to match_array(@instance_types_32)
    end

    it "#allowed_instance_types with 64-bit and pv image" do
      template.hardware = FactoryGirl.create(:hardware, :bitness => 64, :virtualization_type => 'paravirtual')
      expect(workflow.allowed_instance_types.collect { |_, v| v }).to match_array(@instance_types_64)
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
      expect(workflow.allowed_instance_types.collect { |_, v| v }).to be_empty
    end

    it "#allowed_instance_types with 64-bit, pv and ebs" do
      template.hardware = FactoryGirl.create(:hardware,
                                             :bitness             => 64,
                                             :virtualization_type => 'paravirtual',
                                             :root_device_type    => 'ebs')
      expect(workflow.allowed_instance_types.collect { |_, v| v }).to match_array(@instance_types_64)
    end
  end

  describe "#make_request" do
    let(:alt_user) { FactoryGirl.create(:user_with_group) }
    it "creates and update a request" do
      stub_dialog(:get_pre_dialogs)
      stub_dialog(:get_dialogs)

      # if running_pre_dialog is set, it will run 'continue_request'
      workflow = described_class.new(values = {:running_pre_dialog => false}, admin)

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

      request = workflow.make_request(nil, values)

      expect(request).to be_valid
      expect(request).to be_a_kind_of(MiqProvisionRequest)
      expect(request.request_type).to eq("template")
      expect(request.description).to eq("Provision from [#{template.name}] to [New VM]")
      expect(request.requester).to eq(admin)
      expect(request.userid).to eq(admin.userid)
      expect(request.requester_name).to eq(admin.name)

      # updates a request

      stub_get_next_vm_name

      workflow = described_class.new(values, alt_user)

      expect(AuditEvent).to receive(:success).with(
        :event        => "vm_provision_request_updated",
        :target_class => "Vm",
        :userid       => alt_user.userid,
        :message      => "VM Provisioning request updated by <#{alt_user.userid}> for Vm:#{template.id}"
      )
      workflow.make_request(request, values)
    end
  end
end
