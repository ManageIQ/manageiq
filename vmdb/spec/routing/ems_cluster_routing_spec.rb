require "spec_helper"
require "routing/shared_examples"

describe EmsClusterController do
  let(:controller_name) { "ems_cluster" }

  it_behaves_like "A controller that has advanced search routes"
  it_behaves_like "A controller that has compare routes"
  it_behaves_like "A controller that has download_data routes"
  it_behaves_like "A controller that has policy protect routes"
  it_behaves_like "A controller that has tagging routes"
  it_behaves_like "A controller that has timeline routes"

  describe "#button" do
    it "routes with POST" do
      expect(post("/ems_cluster/button")).to route_to("ems_cluster#button")
    end
  end

  describe "#columns_json" do
    it "routes with GET" do
      expect(get("/ems_cluster/columns_json")).to route_to("ems_cluster#columns_json")
    end
  end

  describe "#drift" do
    it "routes with GET" do
      expect(get("/ems_cluster/drift")).to route_to("ems_cluster#drift")
    end
  end

  describe "#drift_history" do
    it "routes with GET" do
      expect(get("/ems_cluster/drift_history")).to route_to("ems_cluster#drift_history")
    end

    it "routes with POST" do
      expect(post("/ems_cluster/drift_history")).to route_to("ems_cluster#drift_history")
    end
  end

  describe "#drift_to_csv" do
    it "routes with GET" do
      expect(get("/ems_cluster/drift_to_csv")).to route_to("ems_cluster#drift_to_csv")
    end
  end

  describe "#drift_to_pdf" do
    it "routes with GET" do
      expect(get("/ems_cluster/drift_to_pdf")).to route_to("ems_cluster#drift_to_pdf")
    end
  end

  describe "#drift_to_txt" do
    it "routes with GET" do
      expect(get("/ems_cluster/drift_to_txt")).to route_to("ems_cluster#drift_to_txt")
    end
  end

  describe "#listnav_search_selected" do
    it "routes with POST" do
      expect(post("/ems_cluster/listnav_search_selected/123")).to route_to(
        "ems_cluster#listnav_search_selected", :id => "123"
      )
    end
  end

  describe "#perf_chart_chooser" do
    it "routes with POST" do
      expect(post("/ems_cluster/perf_chart_chooser")).to route_to("ems_cluster#perf_chart_chooser")
    end
  end

  describe "#perf_top_chart" do
    it "routes with GET" do
      expect(get("/ems_cluster/perf_top_chart")).to route_to("ems_cluster#perf_top_chart")
    end
  end

  describe "#perf_top_chart" do
    it "routes with POST" do
      expect(post("/ems_cluster/perf_top_chart")).to route_to("ems_cluster#perf_top_chart")
    end
  end

  describe "#rows_json" do
    it "routes with GET" do
      expect(get("/ems_cluster/rows_json")).to route_to("ems_cluster#rows_json")
    end
  end

  describe "#save_default_search" do
    it "routes with POST" do
      expect(post("/ems_cluster/save_default_search")).to route_to("ems_cluster#save_default_search")
    end
  end

  describe "#sections_field_changed" do
    it "routes with POST" do
      expect(post("/ems_cluster/sections_field_changed")).to route_to("ems_cluster#sections_field_changed")
    end
  end

  describe "#show" do
    it "routes with GET" do
      expect(get("/ems_cluster/show")).to route_to("ems_cluster#show")
    end
  end

  describe "#show_list" do
    it "routes with GET" do
      expect(get("/ems_cluster/show_list")).to route_to("ems_cluster#show_list")
    end

    it "routes with POST" do
      expect(post("/ems_cluster/show_list")).to route_to("ems_cluster#show_list")
    end
  end
end
