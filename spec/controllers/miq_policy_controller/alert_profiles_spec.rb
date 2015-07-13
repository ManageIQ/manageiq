require "spec_helper"
include UiConstants

describe MiqPolicyController do
  context "::AlertProfiles" do
    before do
      seed_specific_product_features("alert_profile_assign")
    end

    context "#alert_profile_assign" do
      before :each do
        @ap = FactoryGirl.create(:miq_alert_set)
        controller.instance_variable_set(:@sb, {:trees => {:alert_profile_tree => {:active_node => "xx-Vm_ap-#{@ap.id}"}}, :active_tree => :alert_profile_tree})
        controller.stub(:replace_right_cell)
      end

      it "first time in" do
        controller.should_receive(:alert_profile_build_assign_screen)
        controller.alert_profile_assign
        controller.send(:flash_errors?).should_not be_true
      end

      it "Test reset button" do
        controller.instance_variable_set(:@_params, {:id => @ap.id, :button => "reset"})
        controller.should_receive(:alert_profile_build_assign_screen)
        controller.alert_profile_assign
        assigns(:flash_array).first[:message].should include("reset")
        controller.send(:flash_errors?).should_not be_true
      end

      it "Test cancel button" do
        controller.instance_variable_set(:@_params, {:id => @ap.id, :button => "cancel"})
        controller.alert_profile_assign
        assigns(:flash_array).first[:message].should include("cancelled")
        controller.send(:flash_errors?).should_not be_true
      end

      it "Test save button without selecting category" do
        controller.instance_variable_set(:@_params, {:id => @ap.id, :button => "save"})
        controller.instance_variable_set(:@sb, {:trees => {:alert_profile_tree => {:active_node => "xx-Vm_ap-#{@ap.id}"}}, :active_tree => :alert_profile_tree,
                                                :assign => {:alert_profile => @ap, :new => {:assign_to => "Vm-tags", :objects => ["10000000000001"]}}})
        controller.alert_profile_assign
        assigns(:flash_array).first[:message].should_not include("saved")
        controller.send(:flash_errors?).should be_true
      end

      it "Test save button with no errors" do
        controller.instance_variable_set(:@_params, {:id => @ap.id, :button => "save"})
        controller.instance_variable_set(:@sb, {:trees => {:alert_profile_tree => {:active_node => "xx-Vm_ap-#{@ap.id}"}}, :active_tree => :alert_profile_tree,
                                                :assign => {:alert_profile => @ap, :new => {:assign_to => "Vm-tags", :cat => "10000000000001", :objects => ["10000000000001"]}}})
        controller.alert_profile_assign
        assigns(:flash_array).first[:message].should include("saved")
        controller.send(:flash_errors?).should_not be_true
      end
    end
  end
end
