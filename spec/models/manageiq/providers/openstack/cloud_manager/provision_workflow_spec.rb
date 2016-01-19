describe ManageIQ::Providers::Openstack::CloudManager::ProvisionWorkflow do
  include WorkflowSpecHelper

  let(:admin)    { FactoryGirl.create(:user_with_group) }
  let(:provider) do
    allow_any_instance_of(User).to receive(:get_timezone).and_return(Time.zone)
    FactoryGirl.create(:ems_openstack)
  end

  let(:template) { FactoryGirl.create(:template_openstack, :name => "template", :ext_management_system => provider) }

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
          sg = FactoryGirl.create(:security_group_amazon, :name => "sg_1", :ext_management_system => provider)
          provider.security_groups << sg
          filtered = workflow.send(:get_targets_for_ems, provider, :cloud_filter, SecurityGroup,
                                   'security_groups.non_cloud_network')
          expect(filtered.size).to eq(1)
          expect(filtered.first.name).to eq(sg.name)
        end
      end

      context "cloud network" do
        it "#get_targets_for_ems" do
          cn1 = FactoryGirl.create(:cloud_network, :ext_management_system => provider)
          sg_cn = FactoryGirl.create(:security_group_amazon, :name => "sg_2", :ext_management_system => provider,
                                     :cloud_network => cn1)
          provider.security_groups << sg_cn
          filtered = workflow.send(:get_targets_for_ems, provider, :cloud_filter, SecurityGroup, 'security_groups')
          expect(filtered.size).to eq(1)
          expect(filtered.first.name).to eq(sg_cn.name)
        end
      end
    end

    context "Instance Type (Flavor)" do
      it "#get_targets_for_ems" do
        flavor = FactoryGirl.create(:flavor_openstack, :name => "test_flavor_2")
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
      admin.current_group.set_managed_filters([['/managed/cc/001']])
      admin.current_group.set_belongsto_filters([])
      admin.current_group.save

      2.times { FactoryGirl.create(:availability_zone_amazon, :ems_id => provider.id) }
      2.times { FactoryGirl.create(:security_group_amazon, :name => "sgb_1", :ext_management_system => provider) }
      ct1 = FactoryGirl.create(:cloud_tenant, :name => "admin1")
      ct2 = FactoryGirl.create(:cloud_tenant, :name => "admin2")
      provider.cloud_tenants << ct1
      provider.cloud_tenants << ct2
      provider.flavors << FactoryGirl.create(:flavor_openstack, :name => "test_flavor_3")
      provider.flavors << FactoryGirl.create(:flavor_openstack, :name => "test_flavor_4")

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

    context "With a Valid Template" do
      let(:workflow) do
        stub_dialog
        allow_any_instance_of(described_class).to receive(:update_field_visibility)
        described_class.new({:src_vm_id => template.id}, admin.userid)
      end

      context "with empty relationships" do
        it "#allowed_instance_types" do
          expect(workflow.allowed_instance_types).to eq({})
        end

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
        it "#allowed_instance_types" do
          flavor = FactoryGirl.create(:flavor, :name => "flavor_1")
          provider.flavors << flavor
          expect(workflow.allowed_instance_types).to eq(flavor.id => flavor.name)
        end

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
          sg = FactoryGirl.create(:security_group_openstack, :name => "sq_1")
          provider.security_groups << sg
          expect(workflow.allowed_security_groups).to eq(sg.id => sg.name)
        end
      end

      context "#display_name_for_name_description" do
        let(:flavor) { FactoryGirl.create(:flavor_openstack, :name => "test_flavor") }

        it "with name only" do
          expect(workflow.display_name_for_name_description(flavor)).to eq("test_flavor")
        end

        it "with name and description" do
          flavor.description = "Small"
          expect(workflow.display_name_for_name_description(flavor)).to eq("test_flavor: Small")
        end
      end

      context "tenant filtering" do
        before do
          @ct1 = FactoryGirl.create(:cloud_tenant, :name => "admin1")
          @ct2 = FactoryGirl.create(:cloud_tenant, :name => "admin2")
          provider.cloud_tenants << @ct1
          provider.cloud_tenants << @ct2
        end

        context "cloud networks" do
          before do
            @cn1 = FactoryGirl.create(:cloud_network, :name => "cn1")
            @cn2 = FactoryGirl.create(:cloud_network, :name => "cn2")
            provider.cloud_networks << @cn1
            provider.cloud_networks << @cn2
            @ct1.cloud_networks << @cn1
            @ct2.cloud_networks << @cn2
          end

          it "#allowed_cloud_networks with tenant selected" do
            workflow.values.merge!(:cloud_tenant => @ct2.id)
            cns = workflow.allowed_cloud_networks
            expect(cns.keys).to match_array [@cn2.id]
          end

          it "#allowed_cloud_networks with tenant not selected" do
            cns = workflow.allowed_cloud_networks
            expect(cns.keys).to match_array [@cn2.id, @cn1.id]
          end
        end

        context "security groups" do
          before do
            @sg1 = FactoryGirl.create(:security_group_openstack, :name => "sg1")
            @sg2 = FactoryGirl.create(:security_group_openstack, :name => "sg2")
            provider.security_groups << @sg1
            provider.security_groups << @sg2
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
            @ip1 = FactoryGirl.create(:floating_ip, :address => "1.1.1.1")
            @ip2 = FactoryGirl.create(:floating_ip, :address => "2.2.2.2")
            provider.floating_ips << @ip1
            provider.floating_ips << @ip2
            @ct1.floating_ips << @ip1
            @ct2.floating_ips << @ip2
          end

          it "#allowed_floating_ip_addresses with tenant selected" do
            workflow.values.merge!(:cloud_tenant => @ct2.id)
            ips = workflow.allowed_floating_ip_addresses
            expect(ips.keys).to match_array [@ip2.id]
          end

          it "#allowed_floating_ip_addresses with tenant not selected" do
            ips = workflow.allowed_floating_ip_addresses
            expect(ips.keys).to match_array [@ip2.id, @ip1.id]
          end
        end
      end
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
