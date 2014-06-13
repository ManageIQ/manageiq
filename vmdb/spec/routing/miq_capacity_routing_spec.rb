require "spec_helper"
require "routing/shared_examples"

describe MiqCapacityController do
  let(:controller_name) { "miq_capacity" }

  it_behaves_like "A controller that has utilization routes"

  describe "no action" do
    it "routes with GET" do
      expect(get("/miq_capacity")).to route_to("miq_capacity#index")
    end
  end

  describe "#bottlenecks" do
    it "routes with GET" do
      expect(get("/miq_capacity/bottlenecks")).to route_to("miq_capacity#bottlenecks")
    end
  end

  describe "#bottleneck_tl_chooser" do
    it "routes with POST" do
      expect(post("/miq_capacity/bottleneck_tl_chooser")).to route_to("miq_capacity#bottleneck_tl_chooser")
    end
  end

  describe "#change_tab" do
    it "routes with POST" do
      expect(post("/miq_capacity/change_tab")).to route_to("miq_capacity#change_tab")
    end
  end

  describe "#index" do
    it "routes with GET" do
      expect(get("/miq_capacity/index")).to route_to("miq_capacity#index")
    end
  end

  describe "#optimize_tree_select" do
    it "routes with POST" do
      expect(post("/miq_capacity/optimize_tree_select")).to route_to("miq_capacity#optimize_tree_select")
    end
  end

  describe "#planning" do
    it "routes with GET" do
      expect(get("/miq_capacity/planning")).to route_to("miq_capacity#planning")
    end

    it "routes with POST" do
      expect(post("/miq_capacity/planning")).to route_to("miq_capacity#planning")
    end
  end

  describe "#planning_option_changed" do
    it "routes with POST" do
      expect(post("/miq_capacity/planning_option_changed")).to route_to("miq_capacity#planning_option_changed")
    end
  end

  describe "#planning_report_download" do
    it "routes with GET" do
      expect(get("/miq_capacity/planning_report_download")).to route_to("miq_capacity#planning_report_download")
    end
  end

  describe "#tree_autoload_dynatree" do
    it "routes with POST" do
      expect(post("/miq_capacity/tree_autoload_dynatree")).to route_to("miq_capacity#tree_autoload_dynatree")
    end
  end

  describe "#wait_for_task" do
    it "routes with POST" do
      expect(post("/miq_capacity/wait_for_task")).to route_to("miq_capacity#wait_for_task")
    end
  end
end
