describe ApplicationController do
  let(:basic_settings) {
    { "perpage" => 10, "current" => 1, "items" => 0, "total" => 0, "sort_dir" => "DESC", "sort_col" => 0 }
  }
  before do
    stub_user(:features => :all)
  end

  context "#report_data" do
    before(:each) do
      controller.instance_variable_set(:@_response, ActionDispatch::TestResponse.new)
    end
    it "should return report data for VM" do
      controller.instance_variable_set(:@_params, :active_tree => "vandt_tree")
      controller.instance_variable_set(:@_params, :model => "manageiq/providers/infra_manager/vms")
      report_data = JSON.parse(controller.report_data)
      expect(report_data["settings"]).to eql(basic_settings)
      headder = report_data["data"]["head"]
      expect(headder[0]).to eql("is_narrow" => true)
      expect(headder[1]).to eql("is_narrow"=>true)
      expect(headder[2]).to eql("text" => "Name", "sort" => "str", "col_idx" => 0, "align" => "left")
      expect(headder[3]).to eql("text" => "Provider", "sort" => "str", "col_idx" => 1, "align" => "left")
      expect(headder[4]).to eql("text" => "Cluster", "sort" => "str", "col_idx" => 2, "align" => "left")
    end

    it "should call specific functions" do
      allow(controller).to receive(:process_params_options)
      allow(controller).to receive(:process_params_model_view)
      allow(controller).to receive(:get_view)
      allow(controller).to receive(:view_to_hash)
      controller.report_data
      expect(controller).to have_received(:process_params_options)
      expect(controller).to have_received(:process_params_model_view)
      expect(controller).to have_received(:get_view)
      expect(controller).to have_received(:view_to_hash)
    end
  end

  context "#process_params_model_view" do
    it "should call vm_model_from_active_tree" do
      allow(controller).to receive(:vm_model_from_active_tree)
      controller.send(:process_params_model_view, {:active_tree => "vandt_tree"}, {})
      expect(controller).to have_received(:vm_model_from_active_tree)
    end

    it "should call controller_to_model" do
      allow(controller).to receive(:controller_to_model)
      controller.send(:process_params_model_view, {}, {})
      expect(controller).to have_received(:controller_to_model)
    end

    it "should return correct model from params" do
      options = controller.send(:process_params_model_view, {:model => "manageiq/providers/middleware_managers"}, {})
      expect(options).to eql(ManageIQ::Providers::MiddlewareManager)
    end

    it "should return correct model from options" do
      options = controller.send(:process_params_model_view, {}, {:model => "ManageIQ::Providers::MiddlewareManager"})
      expect(options).to eql(ManageIQ::Providers::MiddlewareManager)
    end
  end

  context "#process_params_options" do
    it "should call get node info" do
      allow(controller).to receive(:get_node_info)
      controller.send(
        :process_params_options,
        { :explorer => "true", :active_tree => "vandt_tree", :model_id => "e-2", :controller => "vm_infra" }
      )
      expect(controller).to have_received(:get_node_info)
    end
  end
end
