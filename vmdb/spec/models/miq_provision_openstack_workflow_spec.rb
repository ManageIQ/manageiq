require "spec_helper"

describe MiqProvisionOpenstackWorkflow do
  before do
    MiqRegion.seed
  end

  context "With a user" do
    let(:admin) { FactoryGirl.create(:user, :name => 'admin', :userid => 'admin') }

    it "pass platform attributes to automate" do
      MiqProvisionWorkflow.any_instance.stub(:get_dialogs).and_return(:dialogs => {})
      MiqAeEngine.should_receive(:resolve_automation_object)
      MiqAeEngine.should_receive(:create_automation_object) do |name, attrs, _options|
        name.should eq("REQUEST")
        attrs.should have_attributes(
          'request'                   => 'UI_PROVISION_INFO',
          'message'                   => 'get_pre_dialog_name',
          'dialog_input_request_type' => 'template',
          'dialog_input_target_type'  => 'vm',
          'platform_category'         => 'cloud',
          'platform'                  => 'openstack'
        )
      end

      MiqProvisionOpenstackWorkflow.new({}, admin.userid)
    end

    context "With a Valid Template" do
      let(:provider) { FactoryGirl.create(:ems_openstack) }
      let(:template) { FactoryGirl.create(:template_openstack, :name => "template", :ext_management_system => provider) }
      let(:workflow) do
        MiqProvisionWorkflow.any_instance.stub(:get_dialogs).and_return(:dialogs => {})
        MiqProvisionCloudWorkflow.any_instance.stub(:update_field_visibility)
        MiqProvisionOpenstackWorkflow.new({:src_vm_id => template.id}, admin.userid)
      end

      context "with empty relationships" do
        it "#allowed_instance_types" do
          workflow.allowed_instance_types.should == {}
        end

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
        it "#allowed_instance_types" do
          flavor = FactoryGirl.create(:flavor, :name => "flavor_1")
          provider.flavors << flavor
          workflow.allowed_instance_types.should == {flavor.id => flavor.name}
        end

        it "#allowed_availability_zones" do
          az = FactoryGirl.create(:availability_zone_openstack)
          provider.availability_zones << az
          workflow.allowed_availability_zones.should == {az.id => az.name}
        end

        it "#allowed_availability_zones with NULL AZ" do
          provider.availability_zones << az = FactoryGirl.create(:availability_zone_openstack)
          provider.availability_zones << FactoryGirl.create(:availability_zone_openstack_null, :ems_ref => "null_az")

          azs = workflow.allowed_availability_zones
          azs.length.should == 1
          azs.first.should  == [az.id, az.name]
        end

        it "#allowed_guest_access_key_pairs" do
          kp = AuthPrivateKey.create(:name => "auth_1")
          provider.key_pairs << kp
          workflow.allowed_guest_access_key_pairs.should == {kp.id => kp.name}
        end

        it "#allowed_security_groups" do
          sg = FactoryGirl.create(:security_group_openstack, :name => "sq_1")
          provider.security_groups << sg
          workflow.allowed_security_groups.should == {sg.id => sg.name}
        end
      end

      context "#display_name_for_name_description" do
        let(:flavor)   { FactoryGirl.create(:flavor_openstack, :name => "test_flavor") }

        it "with name only" do
          workflow.display_name_for_name_description(flavor).should == "test_flavor"
        end

        it "with name and description" do
          flavor.description = "Small"
          workflow.display_name_for_name_description(flavor).should == "test_flavor: Small"
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
            cns.keys.should match_array [@cn2.id]
          end

          it "#allowed_cloud_networks with tenant not selected" do
            cns = workflow.allowed_cloud_networks
            cns.keys.should match_array [@cn2.id, @cn1.id]
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
            sgs.keys.should match_array [@sg2.id]
          end

          it "#allowed_security_groups with tenant not selected" do
            sgs = workflow.allowed_security_groups
            sgs.keys.should match_array [@sg2.id, @sg1.id]
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
            ips.keys.should match_array [@ip2.id]
          end

          it "#allowed_floating_ip_addresses with tenant not selected" do
            ips = workflow.allowed_floating_ip_addresses
            ips.keys.should match_array [@ip2.id, @ip1.id]
          end
        end
      end
    end
  end
end
