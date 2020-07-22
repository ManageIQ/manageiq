RSpec.describe ManageIQ::Providers::CloudManager::ProvisionWorkflow do
  include Spec::Support::WorkflowHelper

  let(:admin) { FactoryBot.create(:user_with_group) }
  let(:ems) { FactoryBot.create(:ems_cloud) }
  let(:network_manager) { ems.network_manager }
  let(:template) { FactoryBot.create(:miq_template, :name => "template", :ext_management_system => ems) }

  let(:cloud_init_template) { FactoryBot.create(:customization_template_cloud_init) }
  let(:sysprep_template) { FactoryBot.create(:customization_template_sysprep) }

  let(:workflow) do
    stub_dialog
    allow(User).to receive_messages(:server_timezone => "UTC")
    allow_any_instance_of(described_class).to receive(:update_field_visibility)
    described_class.new({:src_vm_id => template.id, :customization_template_id => cloud_init_template.id}, admin.userid)
  end

  let(:sysprep_workflow) do
    stub_dialog
    allow(User).to receive_messages(:server_timezone => "UTC")
    allow_any_instance_of(described_class).to receive(:update_field_visibility)
    described_class.new({:src_vm_id => template.id, :customization_template_id => sysprep_template.id}, admin.userid)
  end

  context "with allowed customization templates" do
    it "#allowed_customization_templates" do
      expect(workflow.allowed_customization_templates.first).to be_a(OpenStruct)
      expect(sysprep_workflow.allowed_customization_templates.first).to be_a(OpenStruct)
    end

    it "should retrieve cloud-init templates when cloning" do
      options = {'key' => 'value' }

      result = workflow.allowed_customization_templates(options)
      customization_template = workflow.instance_variable_get(:@values)[:customization_template_script]
      template_hash = result.first.to_h

      expect(customization_template).to eq cloud_init_template.script
      expect(template_hash).to be_a(Hash)
      %i(id name description).each do |attr|
        expect(template_hash[attr]).to eq cloud_init_template.send(attr)
      end
    end

    it "should retrieve sysprep templates when cloning" do
      options = {'key' => 'value' }
      allow(sysprep_workflow).to receive(:supports_sysprep?).and_return(true)
      allow(sysprep_workflow).to receive(:load_ar_obj).and_return(template)
      allow(template).to receive(:platform).and_return('windows')

      result = sysprep_workflow.allowed_customization_templates(options)
      customization_template = sysprep_workflow.instance_variable_get(:@values)[:customization_template_script]
      template_hash = result.first.to_h

      expect(customization_template).to eq sysprep_template.script
      expect(template_hash).to be_a(Hash)
      %i(id name description).each do |attr|
        expect(template_hash[attr]).to eq sysprep_template.send(attr)
      end
    end
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
      az = FactoryBot.create(:availability_zone)
      ems.availability_zones << az
      expect(workflow.allowed_availability_zones).to be_empty
    end

    it "#allowed_guest_access_key_pairs" do
      kp = ems.key_pairs.create(:name => "auth_1")
      expect(workflow.allowed_guest_access_key_pairs).to eq(kp.id => kp.name)
    end
  end

  context "without applied tags" do
    context "availability_zones" do
      it "#get_targets_for_ems" do
        az = FactoryBot.create(:availability_zone)
        ems.availability_zones << az
        filtered = workflow.send(:get_targets_for_ems, ems, :cloud_filter, AvailabilityZone,
                                 'availability_zones')
        expect(filtered.size).to eq(1)
        expect(filtered.first.name).to eq(az.name)
      end

      it "returns an empty array when no targets are found" do
        filtered = workflow.send(:get_targets_for_ems, ems, :cloud_filter, AvailabilityZone,
                                 'availability_zones')
        expect(filtered).to eq([])
      end
    end

    context "floating_ips" do
      it "#get_targets_for_source" do
        fip1 = FactoryBot.create(:floating_ip, :cloud_network_only    => true,
                                                :ext_management_system => ems.network_manager)
        filtered = workflow.send(:get_targets_for_source, ems, :cloud_filter, FloatingIp,
                                 'floating_ips.available')
        expect(filtered.size).to eq(1)
        expect(filtered.first.name).to eq(fip1.name)
      end
    end
  end

  context "with applied tags" do
    before do
      FactoryBot.create(:classification_cost_center_with_tags)
      admin.current_group.entitlement = Entitlement.create!(:filters => {'managed'   => [['/managed/cc/001']],
                                                                         'belongsto' => []})
      FactoryBot.create_list(:availability_zone, 2, :ems_id => ems.id)
      FactoryBot.create_list(:security_group, 2, :name => "sgb_1", :ext_management_system => ems.network_manager)

      ems.key_pairs = FactoryBot.create_list(:auth_key_pair_cloud, 2)
      ems.flavors << FactoryBot.create(:flavor, :name => "t1.micro", :supports_32_bit => true, :supports_64_bit => true)
      ems.flavors << FactoryBot.create(:flavor, :name => "m1.large", :supports_32_bit => false, :supports_64_bit => true)

      tagged_key_pair = ems.key_pairs.first
      tagged_zone = ems.availability_zones.first
      tagged_flavor = ems.flavors.first

      Classification.classify(tagged_zone, 'cc', '001')
      Classification.classify(tagged_flavor, 'cc', '001')
      Classification.classify(tagged_key_pair, 'cc', '001')
    end

    context "key_pairs" do
      it "#get_targets_for_ems" do
        expect(ems.key_pairs.size).to eq(2)
        expect(ems.key_pairs.first.tags.size).to eq(1)
        expect(ems.key_pairs.last.tags.size).to eq(0)
        filtered = workflow.send(:get_targets_for_ems, ems, :cloud_filter, ManageIQ::Providers::CloudManager::AuthKeyPair,
                                 'key_pairs')
        expect(filtered.size).to eq(1)
      end
    end

    context "availability_zones" do
      it "#get_targets_for_ems" do
        expect(ems.availability_zones.size).to eq(2)
        expect(ems.availability_zones.first.tags.size).to eq(1)
        expect(ems.availability_zones.last.tags.size).to eq(0)
        filtered = workflow.send(:get_targets_for_ems, ems, :cloud_filter, AvailabilityZone,
                                 'availability_zones')
        expect(filtered.size).to eq(1)
      end
    end
  end

  context "with VPC relationships" do
    before do
      @az1 = FactoryBot.create(:availability_zone, :ext_management_system => ems)
      @az2 = FactoryBot.create(:availability_zone, :ext_management_system => ems)
      @az3 = FactoryBot.create(:availability_zone, :ext_management_system => ems)

      @cn1 = FactoryBot.create(:cloud_network, :ext_management_system => ems.network_manager, :cidr => "10.0.0./8")

      @cs1 = FactoryBot.create(:cloud_subnet, :cloud_network         => @cn1,
                                               :availability_zone     => @az1,
                                               :ext_management_system => ems.network_manager)
      @cs2 = FactoryBot.create(:cloud_subnet, :cloud_network         => @cn1,
                                               :availability_zone     => @az2,
                                               :ext_management_system => ems.network_manager)
      @ip1 = FactoryBot.create(:floating_ip, :cloud_network_only    => true,
                                              :ext_management_system => ems.network_manager)
      @ip2 = FactoryBot.create(:floating_ip, :cloud_network_only    => false,
                                              :ext_management_system => ems.network_manager)
    end

    context "#allowed_cloud_networks" do
      it "without a zone", :skip_before do
        expect(workflow.allowed_cloud_networks.length).to eq(1)
      end

      it "with a zone" do
        workflow.values[:placement_availability_zone] = [@az1.id, @az1.name]
        expect(workflow.allowed_cloud_networks.length).to eq(1)
        expect(workflow.allowed_cloud_networks).to eq(@cn1.id => "#{@cn1.name} (#{@cn1.cidr})")
      end
    end

    context "#allowed_cloud_subnets" do
      it "without a cloud_network", :skip_before do
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
      it "returns floating_ip_addresses" do
        expect(workflow.allowed_floating_ip_addresses).to eq(@ip1.id => @ip1.address, @ip2.id => @ip2.address)
      end
    end

    context "#supports_sysprep?" do
      it "returns the expected boolean value" do
        expect(workflow.supports_sysprep?).to eql(false)
      end
    end
  end
end
