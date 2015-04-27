require "spec_helper"

describe ApplicationController do
  before do
    controller.instance_variable_set(:@sb, {})
    ur = FactoryGirl.create(:miq_user_role)
    rptmenu = {:report_menus => [
                                    ["Configuration Management",["Hosts",["Hosts Summary", "Hosts Summary"]]]
                                ]
              }
    group = FactoryGirl.create(:miq_group, :miq_user_role => ur, :settings => rptmenu)
    user = FactoryGirl.create(:user, :userid => 'wilma', :miq_groups => [group])
    session[:group] = user.current_group.id
    session[:userid] = user.userid
  end

  context "#find_by_id_filtered" do
    it "Verify Invalid input flash error message when invalid id is passed in" do
      lambda { controller.send(:find_by_id_filtered, ExtManagementSystem, "invalid") }.should raise_error(RuntimeError, "Invalid input")
    end

    it "Verify flash error message when passed in id no longer exists in database" do
      lambda { controller.send(:find_by_id_filtered, ExtManagementSystem, "1") }.should raise_error(RuntimeError, "Selected Provider no longer exists")
    end

    it "Verify record gets set when valid id is passed in" do
      ems = FactoryGirl.create(:ext_management_system)
      session[:userid] = "test"
      record = controller.send(:find_by_id_filtered, ExtManagementSystem, ems.id)
      record.should be_a_kind_of(ExtManagementSystem)
    end
  end

  context "#assert_privileges" do
    before do
      EvmSpecHelper.seed_specific_product_features("host_new", "host_edit", "perf_reload")
      feature = MiqProductFeature.find_all_by_identifier(["host_new"])
      test_user_role  = FactoryGirl.create(:miq_user_role,
                                           :name                 => "test_user_role",
                                           :miq_product_features => feature)
      test_user_group = FactoryGirl.create(:miq_group, :miq_user_role => test_user_role)
      user = FactoryGirl.create(:user, :name => 'test_user', :miq_groups => [test_user_group])
      User.stub(:current_user => user)
    end

    it "should not raise an error for feature that user has access to" do
      msg = "The user is not authorized for this task or item."
      lambda do
        controller.send(:assert_privileges, "host_new")
      end.should_not raise_error
    end

    it "should raise an error for feature that user does not have access to" do
      msg = "The user is not authorized for this task or item."
      lambda do
        controller.send(:assert_privileges, "host_edit")
      end.should raise_error(MiqException::RbacPrivilegeException, msg)
    end

    it "should not raise an error for common hidden feature under a hidden parent" do
      lambda do
        controller.send(:assert_privileges, "perf_reload")
      end.should_not raise_error
    end
  end

  context "#view_yaml_filename" do
    before do
      EvmSpecHelper.seed_specific_product_features("vm_infra_explorer", "host_edit")
      feature = MiqProductFeature.find_all_by_identifier("vm_infra_explorer")
      @test_user_role  = FactoryGirl.create(:miq_user_role,
                                            :name                 => "test_user_role",
                                            :miq_product_features => feature)
      test_user_group = FactoryGirl.create(:miq_group, :miq_user_role => @test_user_role)
      user = FactoryGirl.create(:user, :name => 'test_user', :miq_groups => [test_user_group])
      User.stub(:current_user => user)
    end

    it "should return restricted view yaml for restricted user" do
      @test_user_role[:settings] = {:restrictions => {:vms => :user_or_group}}
      view_yaml = controller.send(:view_yaml_filename, "VmCloud", {})
      view_yaml.should include("Vm__restricted.yaml")
    end

    it "should return VmCloud view yaml for non-restricted user" do
      @test_user_role[:settings] = {}
      view_yaml = controller.send(:view_yaml_filename, "VmCloud", {})
      view_yaml.should include("VmCloud.yaml")
    end
  end

  context "#find_checked_items" do
    it "returns empty array when button is pressed from summary screen with params as symbol" do
      controller.instance_variable_set(:@_params, :id => "1")
      result = controller.send(:find_checked_items)
      result.should eq([])
    end

    it "returns empty array when button is pressed from summary screen with params as string" do
      controller.instance_variable_set(:@_params, "id" => "1")
      result = controller.send(:find_checked_items)
      result.should eq([])
    end

    it "returns list of items selected from list view" do
      controller.instance_variable_set(:@_params, :miq_grid_checks => "1, 2, 3, 4")
      result = controller.send(:find_checked_items)
      result.count eq(4)
      result.should eq([1, 2, 3, 4])
    end
  end

  context "#render_gtl_view_tb?" do
    before do
      controller.instance_variable_set(:@layout, "host")
      controller.instance_variable_set(:@gtl_type, "list")
    end

    it "returns true for list views" do
      controller.instance_variable_set(:@_params, :action => "show_list")
      result = controller.send(:render_gtl_view_tb?)
      result.should eq(true)
    end

    it "returns true for list views when navigating thru relationships" do
      controller.instance_variable_set(:@_params, :action => "show")
      result = controller.send(:render_gtl_view_tb?)
      result.should eq(true)
    end

    it "returns false for sub list views" do
      controller.instance_variable_set(:@_params, :action => "host_services")
      result = controller.send(:render_gtl_view_tb?)
      result.should eq(false)
    end
  end
end
