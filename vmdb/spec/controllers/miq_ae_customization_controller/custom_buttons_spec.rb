require "spec_helper"
include UiConstants

describe MiqAeCustomizationController do
  context "::CustomButtons" do
    context "#ab_get_node_info" do
      it "correct target class gets set when assigned button node is clicked" do
        custom_button = FactoryGirl.create(:custom_button, :applies_to_class => "Host", :name => "Some Name")
        target_classes = {}
        CustomButton.button_classes.each{|db| target_classes[db] = ui_lookup(:model=>db)}
        controller.instance_variable_set(:@sb, {:target_classes => target_classes})
        controller.instance_variable_set(:@temp, {})
        controller.send(:ab_get_node_info, "xx-ab_Host_cbg-10r95_cb-#{custom_button.id}")
        assigns(:resolve)[:new][:target_class].should == "Host"
      end
    end
  end
end
