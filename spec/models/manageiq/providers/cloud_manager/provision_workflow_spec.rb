describe ManageIQ::Providers::CloudManager::ProvisionWorkflow do
  include Spec::Support::WorkflowHelper

  let(:admin) { FactoryGirl.create(:user_with_group) }
  let(:ems) { FactoryGirl.create(:ems_cloud) }
  let(:template) { FactoryGirl.create(:miq_template, :name => "template", :ext_management_system => ems) }
  let(:workflow) do
    stub_dialog
    allow_any_instance_of(User).to receive(:get_timezone).and_return(Time.zone)
    allow_any_instance_of(described_class).to receive(:update_field_visibility)
    described_class.new({:src_vm_id => template.id}, admin.userid)
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
      az = FactoryGirl.create(:availability_zone)
      ems.availability_zones << az
      expect(workflow.allowed_availability_zones).to be_empty
    end

    it "#allowed_guest_access_key_pairs" do
      kp = AuthPrivateKey.create(:name => "auth_1")
      ems.key_pairs << kp
      expect(workflow.allowed_guest_access_key_pairs).to eq(kp.id => kp.name)
    end
  end

  context "without applied tags" do
    context "availability_zones" do
      it "#get_targets_for_ems" do
        az = FactoryGirl.create(:availability_zone)
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
        fip1 = FactoryGirl.create(:floating_ip, :cloud_network_only    => true,
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
      FactoryGirl.create(:classification_cost_center_with_tags)
      admin.current_group.entitlement = Entitlement.create!(:filters => {'managed'   => [['/managed/cc/001']],
                                                                         'belongsto' => []})
      2.times do |i|
        kp = ManageIQ::Providers::CloudManager::AuthKeyPair.create(:name => "auth_#{i}")
        ems.key_pairs << kp
      end
      2.times { FactoryGirl.create(:availability_zone, :ems_id => ems.id) }
      2.times do
        FactoryGirl.create(:security_group, :name                  => "sgb_1",
                                            :ext_management_system => ems.network_manager)
      end
      ems.flavors << FactoryGirl.create(:flavor, :name => "t1.micro", :supports_32_bit => true,
                                        :supports_64_bit => true)
      ems.flavors << FactoryGirl.create(:flavor, :name => "m1.large", :supports_32_bit => false,
                                        :supports_64_bit => true)
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
      @az1 = FactoryGirl.create(:availability_zone, :ext_management_system => ems)
      @az2 = FactoryGirl.create(:availability_zone, :ext_management_system => ems)
      @az3 = FactoryGirl.create(:availability_zone, :ext_management_system => ems)

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
  end
end
