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
        MiqProvisionWorkflow.any_instance.stub(:get_dialogs).and_return( {:dialogs => {}} )
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
    end
  end
end
