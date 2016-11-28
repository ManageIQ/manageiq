describe ManageIQ::Providers::Openstack::CloudManager::ProvisionWorkflow do
  include Spec::Support::WorkflowHelper

  let(:admin)    { FactoryGirl.create(:user_with_group) }
  let(:provider) do
    allow_any_instance_of(User).to receive(:get_timezone).and_return(Time.zone)
    FactoryGirl.create(:ems_openstack)
  end

  let(:template) { FactoryGirl.create(:template_openstack, :ext_management_system => provider) }

  context "without applied tags" do
    let(:workflow) do
      stub_dialog
      allow_any_instance_of(described_class).to receive(:update_field_visibility)
      described_class.new({:src_vm_id => template.id}, admin.userid)
    end
    context "availability_zones" do
      it "#get_targets_for_ems" do
        az = FactoryGirl.create(:availability_zone_amazon)
        provider.availability_zones << az
        filtered = workflow.send(:get_targets_for_ems, provider, :cloud_filter, AvailabilityZone,
                                 'availability_zones.available')
        expect(filtered.size).to eq(1)
        expect(filtered.first.name).to eq(az.name)
      end

      it "returns an empty array when no targets are found" do
        filtered = workflow.send(:get_targets_for_ems, provider, :cloud_filter, AvailabilityZone,
                                 'availability_zones.available')
        expect(filtered).to eq([])
      end
    end

    context "security_groups" do
      context "non cloud network" do
        it "#get_targets_for_ems" do
          sg = FactoryGirl.create(:security_group_openstack, :ext_management_system => provider.network_manager)
          filtered = workflow.send(:get_targets_for_ems, provider, :cloud_filter, SecurityGroup,
                                   'security_groups.non_cloud_network')
          expect(filtered.size).to eq(1)
          expect(filtered.first.name).to eq(sg.name)
        end
      end

      context "cloud network" do
        it "#get_targets_for_ems" do
          cn1 = FactoryGirl.create(:cloud_network, :ext_management_system => provider.network_manager)
          sg_cn = FactoryGirl.create(:security_group_openstack, :ext_management_system => provider.network_manager, :cloud_network => cn1)
          filtered = workflow.send(:get_targets_for_ems, provider, :cloud_filter, SecurityGroup, 'security_groups')
          expect(filtered.size).to eq(1)
          expect(filtered.first.name).to eq(sg_cn.name)
        end
      end
    end

    context "Instance Type (Flavor)" do
      it "#get_targets_for_ems" do
        flavor = FactoryGirl.create(:flavor_openstack)
        provider.flavors << flavor
        filtered = workflow.send(:get_targets_for_ems, provider, :cloud_filter, Flavor, 'flavors')
        expect(filtered.size).to eq(1)
        expect(filtered.first.name).to eq(flavor.name)
      end
    end
  end

  context "with applied tags" do
    let(:workflow) do
      stub_dialog
      allow_any_instance_of(described_class).to receive(:update_field_visibility)
      described_class.new({:src_vm_id => template.id}, admin.userid)
    end

    before do
      FactoryGirl.create(:classification_cost_center_with_tags)
      admin.current_group.entitlement = Entitlement.create!
      admin.current_group.entitlement.set_managed_filters([['/managed/cc/001']])
      admin.current_group.save!

      2.times { FactoryGirl.create(:availability_zone_amazon, :ems_id => provider.id) }
      2.times { FactoryGirl.create(:security_group_openstack, :ext_management_system => provider.network_manager) }
      ct1 = FactoryGirl.create(:cloud_tenant)
      ct2 = FactoryGirl.create(:cloud_tenant)
      provider.cloud_tenants << ct1
      provider.cloud_tenants << ct2
      provider.flavors << FactoryGirl.create(:flavor_openstack)
      provider.flavors << FactoryGirl.create(:flavor_openstack)

      tagged_zone = provider.availability_zones.first
      tagged_sec = provider.security_groups.first
      tagged_flavor = provider.flavors.first
      tagged_tenant = provider.cloud_tenants.first
      Classification.classify(tagged_zone, 'cc', '001')
      Classification.classify(tagged_sec, 'cc', '001')
      Classification.classify(tagged_flavor, 'cc', '001')
      Classification.classify(tagged_tenant, 'cc', '001')
    end

    context "availability_zones" do
      it "#get_targets_for_ems" do
        expect(provider.availability_zones.size).to eq(2)
        expect(provider.availability_zones.first.tags.size).to eq(1)
        expect(provider.availability_zones.last.tags.size).to eq(0)

        filtered = workflow.send(:get_targets_for_ems, provider, :cloud_filter, AvailabilityZone,
                                 'availability_zones.available')
        expect(filtered.size).to eq(1)
      end
    end

    context "security groups" do
      it "#get_targets_for_ems" do
        expect(provider.security_groups.size).to eq(2)
        expect(provider.security_groups.first.tags.size).to eq(1)
        expect(provider.security_groups.last.tags.size).to eq(0)

        expect(workflow.send(:get_targets_for_ems,
                             provider,
                             :cloud_filter,
                             SecurityGroup,
                             'security_groups').size)
          .to eq(1)
      end
    end

    context "instance types (Flavor)" do
      it "#get_targets_for_ems" do
        expect(provider.flavors.size).to eq(2)
        expect(provider.flavors.first.tags.size).to eq(1)
        expect(provider.flavors.last.tags.size).to eq(0)

        expect(workflow.send(:get_targets_for_ems, provider, :cloud_filter, Flavor, 'flavors').size).to eq(1)
      end
    end

    context "allowed_tenants" do
      it "#get_targets_for_ems" do
        expect(provider.cloud_tenants.size).to eq(2)
        expect(provider.cloud_tenants.first.tags.size).to eq(1)
        expect(provider.cloud_tenants.last.tags.size).to eq(0)

        expect(workflow.send(:get_targets_for_ems, provider, :cloud_filter, CloudTenant, 'cloud_tenants').size).to eq(1)
      end
    end
  end

  context "With a user" do
    it "pass platform attributes to automate" do
      stub_dialog
      assert_automate_dialog_lookup(admin, 'cloud', 'openstack')

      described_class.new({}, admin.userid)
    end

    context "Without a Template" do
      let(:workflow) do
        stub_dialog
        allow_any_instance_of(described_class).to receive(:update_field_visibility)
        described_class.new({}, admin.userid)
      end

      it "#allowed_instance_types" do
        provider.flavors << FactoryGirl.create(:flavor_openstack)

        expect(workflow.allowed_instance_types).to eq({})
      end
    end

    context "With a Valid Template" do
      let(:workflow) do
        stub_dialog
        allow_any_instance_of(described_class).to receive(:update_field_visibility)
        described_class.new({:src_vm_id => template.id}, admin.userid)
      end

      context "#allowed_instance_types" do
        let(:template) { FactoryGirl.create(:template_openstack, :hardware => hardware, :ext_management_system => provider) }

        context "with regular hardware" do
          let(:hardware) { FactoryGirl.create(:hardware, :size_on_disk => 1.gigabyte, :memory_mb_minimum => 512) }

          it "filters flavors too small" do
            flavor = FactoryGirl.create(:flavor_openstack, :memory => 1.gigabyte, :root_disk_size => 1.terabyte)
            provider.flavors << flavor
            provider.flavors << FactoryGirl.create(:flavor_openstack, :memory => 1.gigabyte, :root_disk_size => 1.megabyte) # Disk too small
            provider.flavors << FactoryGirl.create(:flavor_openstack, :memory => 1.megabyte, :root_disk_size => 1.terabyte) # Memory too small

            expect(workflow.allowed_instance_types).to eq(flavor.id => flavor.name)
          end
        end

        context "hardware with no size_on_disk" do
          let(:hardware) { FactoryGirl.create(:hardware, :memory_mb_minimum => 512) }

          it "filters flavors too small" do
            flavor = FactoryGirl.create(:flavor_openstack, :memory => 1.gigabyte, :root_disk_size => 1.terabyte)
            provider.flavors << flavor
            provider.flavors << FactoryGirl.create(:flavor_openstack, :memory => 1.megabyte, :root_disk_size => 1.terabyte) # Memory too small

            expect(workflow.allowed_instance_types).to eq(flavor.id => flavor.name)
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
          az = FactoryGirl.create(:availability_zone_openstack)
          provider.availability_zones << az
          expect(workflow.allowed_availability_zones).to eq(az.id => az.name)
        end

        it "#allowed_availability_zones with NULL AZ" do
          provider.availability_zones << az = FactoryGirl.create(:availability_zone_openstack)
          provider.availability_zones << FactoryGirl.create(:availability_zone_openstack_null, :ems_ref => "null_az")

          azs = workflow.allowed_availability_zones
          expect(azs.length).to eq(1)
          expect(azs.first).to eq([az.id, az.name])
        end

        it "#allowed_guest_access_key_pairs" do
          kp = AuthPrivateKey.create(:name => "auth_1")
          provider.key_pairs << kp
          expect(workflow.allowed_guest_access_key_pairs).to eq(kp.id => kp.name)
        end

        it "#allowed_security_groups" do
          sg = FactoryGirl.create(:security_group_openstack)
          provider.security_groups << sg
          expect(workflow.allowed_security_groups).to eq(sg.id => sg.name)
        end
      end

      context "#display_name_for_name_description" do
        let(:flavor) { FactoryGirl.create(:flavor_openstack) }

        it "with name only" do
          expect(workflow.display_name_for_name_description(flavor)).to eq(flavor.name)
        end

        it "with name and description" do
          flavor.description = "Small"
          expect(workflow.display_name_for_name_description(flavor)).to eq("#{flavor.name}: Small")
        end
      end

      context "tenant filtering" do
        before do
          @ct1 = FactoryGirl.create(:cloud_tenant_openstack)
          @ct2 = FactoryGirl.create(:cloud_tenant_openstack)
          provider.cloud_tenants << @ct1
          provider.cloud_tenants << @ct2
        end

        context "cloud networks" do
          before do
            @cn1 = FactoryGirl.create(:cloud_network_private_openstack,
                                      :cloud_tenant          => @ct1,
                                      :ext_management_system => provider.network_manager)
            @cn2 = FactoryGirl.create(:cloud_network_private_openstack,
                                      :cloud_tenant          => @ct2,
                                      :ext_management_system => provider.network_manager)
            @cn3 = FactoryGirl.create(:cloud_network_public_openstack,
                                      :cloud_tenant          => @ct2,
                                      :ext_management_system => provider.network_manager)

            @cn_shared = FactoryGirl.create(:cloud_network_private_openstack,
                                            :shared                => true,
                                            :cloud_tenant          => @ct2,
                                            :ext_management_system => provider.network_manager)
          end

          it "#allowed_cloud_networks with tenant selected" do
            workflow.values.merge!(:cloud_tenant => @ct2.id)
            cns = workflow.allowed_cloud_networks
            expect(cns.keys).to match_array [@cn2.id, @cn_shared.id]
          end

          it "#allowed_cloud_networks with another tenant selected" do
            workflow.values[:cloud_tenant] = @ct1.id
            cns = workflow.allowed_cloud_networks
            expect(cns.keys).to match_array [@cn1.id, @cn_shared.id]
          end

          it "#allowed_cloud_networks with tenant not selected" do
            cns = workflow.allowed_cloud_networks
            expect(cns.keys).to match_array [@cn2.id, @cn1.id, @cn_shared.id]
          end
        end

        context "security groups" do
          before do
            @sg1 = FactoryGirl.create(:security_group_openstack)
            @sg2 = FactoryGirl.create(:security_group_openstack)
            provider.network_manager.security_groups << @sg1
            provider.network_manager.security_groups << @sg2
            @ct1.security_groups << @sg1
            @ct2.security_groups << @sg2
          end

          it "#allowed_security_groups with tenant selected" do
            workflow.values.merge!(:cloud_tenant => @ct2.id)
            sgs = workflow.allowed_security_groups
            expect(sgs.keys).to match_array [@sg2.id]
          end

          it "#allowed_security_groups with tenant not selected" do
            sgs = workflow.allowed_security_groups
            expect(sgs.keys).to match_array [@sg2.id, @sg1.id]
          end
        end

        context "floating ip" do
          before do
            cloud_network_public   = FactoryGirl.create(:cloud_network_public_openstack)
            cloud_network_public_2 = FactoryGirl.create(:cloud_network_public_openstack)
            router                 = FactoryGirl.create(:network_router_openstack,
                                                        :cloud_network => cloud_network_public)
            @cloud_network         = FactoryGirl.create(:cloud_network_private_openstack,
                                                        :cloud_tenant => @ct2)
            @cloud_network_2       = FactoryGirl.create(:cloud_network_private_openstack,
                                                        :cloud_tenant => @ct2)
            _subnet                = FactoryGirl.create(:cloud_subnet_openstack,
                                                        :network_router        => router,
                                                        :cloud_network         => @cloud_network,
                                                        :ext_management_system => provider.network_manager)

            @ip1 = FactoryGirl.create(:floating_ip,
                                      :address       => "1.1.1.1",
                                      :cloud_tenant  => @ct1,
                                      :cloud_network => cloud_network_public)
            @ip2 = FactoryGirl.create(:floating_ip,
                                      :address       => "2.2.2.2",
                                      :cloud_tenant  => @ct2,
                                      :cloud_network => cloud_network_public)
            @ip3 = FactoryGirl.create(:floating_ip,
                                      :address       => "2.2.2.3",
                                      :cloud_tenant  => @ct2,
                                      :cloud_network => cloud_network_public_2)
          end

          it "#allowed_floating_ip_addresses with tenant selected" do
            workflow.values[:cloud_tenant]  = @ct2.id
            workflow.values[:cloud_network] = @cloud_network.id
            ips = workflow.allowed_floating_ip_addresses
            expect(ips.keys).to match_array [@ip2.id]
          end

          it "#allowed_floating_ip_addresses with tenant not selected" do
            workflow.values[:cloud_network] = @cloud_network.id
            ips = workflow.allowed_floating_ip_addresses
            expect(ips.keys).to match_array [@ip2.id, @ip1.id]
          end

          it "#allowed_floating_ip_addresses with network not connected to the router" do
            workflow.values[:cloud_network] = @cloud_network_2.id
            ips = workflow.allowed_floating_ip_addresses
            expect(ips.keys).to match_array []
          end
        end
      end
    end
  end

  describe "prepare_volumes_fields" do
    let(:workflow) do
      stub_dialog
      allow_any_instance_of(described_class).to receive(:update_field_visibility)
      described_class.new({:src_vm_id => template.id}, admin.userid)
    end
    it "converts numbered volume form fields into an array" do
      volumes = workflow.prepare_volumes_fields(
        :name_1 => "v1n", :size_1 => "v1s", :delete_on_terminate_1 => true,
        :name_2 => "v2n", :size_2 => "v2s", :delete_on_terminate_2 => false,
        :other_irrelevant_key => 1
      )
      expect(volumes.length).to eq(2)
      expect(volumes[0]).to eq(:name => "v1n", :size => "v1s", :delete_on_terminate => true)
      expect(volumes[1]).to eq(:name => "v2n", :size => "v2s", :delete_on_terminate => false)
    end
    it "produces an empty array if there are no volume fields" do
      volumes = workflow.prepare_volumes_fields(:other_irrelevant_key => 1)
      expect(volumes.length).to eq(0)
    end
  end

  describe "#make_request" do
    let(:alt_user) { FactoryGirl.create(:user_with_group) }

    it "creates and update a request" do
      EvmSpecHelper.local_miq_server
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
