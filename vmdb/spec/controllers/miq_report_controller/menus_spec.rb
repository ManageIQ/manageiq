require "spec_helper"
include UiConstants

describe ReportController do
  context "::Menus" do
    context "#menu_update" do
      it "set menus to default" do
        controller.stub(:menu_get_form_vars)
        controller.stub(:get_tree_data)
        controller.stub(:replace_right_cell)
        controller.instance_variable_set(:@temp, {:rpt_menu => []})
        controller.instance_variable_set(:@edit, {:new => {}})
        controller.instance_variable_set(:@sb, {:new => {}})
        controller.instance_variable_set(:@_params, {:button => "default"})
        controller.should_receive(:build_report_listnav).with "reports","menu","default"
        controller.menu_update
        assigns(:flash_array).first[:message].should include("default")
      end
    end
  end
end
