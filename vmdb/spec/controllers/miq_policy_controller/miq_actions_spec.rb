require "spec_helper"
include UiConstants

describe MiqPolicyController do
  context "::MiqActions" do
    context "#action_edit" do
      before :each do
        @action = FactoryGirl.create(:miq_action, :name => "Test_Action")
        controller.instance_variable_set(:@sb, {})
        controller.stub(:replace_right_cell)
        controller.stub(:action_build_cat_tree)
        controller.stub(:get_node_info)
        controller.stub(:action_get_info)
      end

      it "first time in" do
        controller.action_edit
        controller.send(:flash_errors?).should_not be_true
      end

      it "Test reset button" do
        controller.instance_variable_set(:@_params, {:id => @action.id, :button => "reset"})
        controller.action_edit
        assigns(:flash_array).first[:message].should include("reset")
        controller.send(:flash_errors?).should_not be_true
      end

      it "Test cancel button" do
        controller.instance_variable_set(:@sb, {:trees => {:action_tree => {:active_node => "a-#{@action.id}"}}, :active_tree => :action_tree})
        controller.instance_variable_set(:@_params, {:id => @action.id, :button => "cancel"})
        controller.action_edit
        assigns(:flash_array).first[:message].should include("cancelled")
        controller.send(:flash_errors?).should_not be_true
      end

      it "Test saving an action without selecting a Tag" do
        controller.instance_variable_set(:@_params, {:id => @action.id})
        controller.action_edit
        controller.send(:flash_errors?).should_not be_true
        edit = controller.instance_variable_get(:@edit)
        edit[:new][:action_type] = "tag"
        session[:edit] = assigns(:edit)
        controller.instance_variable_set(:@_params, {:id => @action.id, :button => "save"})
        controller.should_receive(:render)
        controller.action_edit
        assigns(:flash_array).first[:message].should include("At least one Tag")
        assigns(:flash_array).first[:message].should_not include("saved")
        controller.send(:flash_errors?).should be_true
      end

      it "Test saving an action after selecting a Tag" do
        controller.instance_variable_set(:@_params, {:id => @action.id})
        controller.action_edit
        controller.send(:flash_errors?).should_not be_true
        edit = controller.instance_variable_get(:@edit)
        edit[:new][:action_type] = "tag"
        edit[:new][:options] = Hash.new
        edit[:new][:options][:tags] = "Some Tag"
        session[:edit] = assigns(:edit)
        controller.instance_variable_set(:@_params, {:id => @action.id, :button => "save"})
        controller.action_edit
        assigns(:flash_array).first[:message].should_not include("At least one Tag")
        assigns(:flash_array).first[:message].should include("saved")
        controller.send(:flash_errors?).should_not be_true
      end
    end
  end
end
