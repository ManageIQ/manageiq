require "spec_helper"
require "routing/shared_examples"

describe "routes for AvailabilityZoneController" do
  let(:controller_name) { "availability_zone" }

  it_behaves_like "A controller that has advanced search routes"
  it_behaves_like "A controller that has compare routes"
  it_behaves_like "A controller that has download_data routes"
  it_behaves_like "A controller that has show list routes"
  it_behaves_like "A controller that has tagging routes"
  it_behaves_like "A controller that has timeline routes"

  describe "#index" do
    it "routes with GET" do
      expect(get("/#{controller_name}")).to route_to("#{controller_name}#index")
    end
  end

  describe "#perf_top_chart" do
    it "routes with GET" do
      expect(get("/#{controller_name}/perf_top_chart")).to route_to("#{controller_name}#perf_top_chart")
    end
  end

  describe "#show" do
    it "routes with GET" do
      expect(get("/#{controller_name}/show/123")).to route_to("#{controller_name}#show", :id => "123")
    end
  end

  describe "#button" do
    it "routes with POST" do
      expect(post("/#{controller_name}/button")).to route_to("#{controller_name}#button")
    end
  end

  describe "#adv_search_toggle" do
    it "routes with POST" do
      expect(post("/#{controller_name}/adv_search_toggle")).to route_to("#{controller_name}#adv_search_toggle")
    end
  end

  describe "#adv_search_load_choice" do
    it "routes with POST" do
      expect(post("/#{controller_name}/adv_search_load_choice")).to route_to(
        "#{controller_name}#adv_search_load_choice"
      )
    end
  end

  describe "#panel_control" do
    it "routes with POST" do
      expect(post("/#{controller_name}/panel_control")).to route_to("#{controller_name}#panel_control")
    end
  end

  describe "#perf_top_chart" do
    it "routes with POST" do
      expect(post("/#{controller_name}/perf_top_chart")).to route_to("#{controller_name}#perf_top_chart")
    end
  end

  describe "#sections_field_changed" do
    it "routes with POST" do
      expect(post("/#{controller_name}/sections_field_changed")).to route_to(
        "#{controller_name}#sections_field_changed"
      )
    end
  end

  describe "#show" do
    it "routes with POST" do
      expect(post("/#{controller_name}/show")).to route_to("#{controller_name}#show")
    end
  end
end
