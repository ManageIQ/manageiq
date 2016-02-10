describe ReportController do
  context "::Menus" do
    context "#menu_update" do
      it "set menus to default" do
        allow(controller).to receive(:menu_get_form_vars)
        allow(controller).to receive(:get_tree_data)
        allow(controller).to receive(:replace_right_cell)
        controller.instance_variable_set(:@rpt_menu, [])
        controller.instance_variable_set(:@edit, {:new => {}})
        controller.instance_variable_set(:@sb, :new => {})
        controller.instance_variable_set(:@_params, :button => "default")
        expect(controller).to receive(:build_report_listnav).with "reports", "menu", "default"
        controller.menu_update
        expect(assigns(:flash_array).first[:message]).to include("default")
      end
    end
  end
end
