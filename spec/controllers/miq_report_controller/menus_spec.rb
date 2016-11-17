describe ReportController do
  describe "#menu_update" do
    let(:rpt_menu) do
      [
        [
          "Configuration Management", [
            ["Virtual Machines", ["VMs with Free Space > 50% by Department"]],
          ]
        ]
      ]
    end

    before do
      controller.instance_variable_set(:@edit, :new => {})
      controller.instance_variable_set(:@sb, :new => {})
      controller.instance_variable_set(:@_params, :button => "default")

      @user = stub_user(features: :all)
    end

    it "set menus to default" do
      expect(controller).to receive(:menu_get_form_vars)
      expect(controller).to receive(:get_tree_data)
      expect(controller).to receive(:replace_right_cell)
      expect(controller).to receive(:get_reports_menu).with(@user.current_group, "reports", "default").and_return(rpt_menu)

      controller.menu_update
      expect(assigns(:flash_array).first[:message]).to include("default")
    end
  end
end
