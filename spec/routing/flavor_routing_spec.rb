require "spec_helper"
require "routing/shared_examples"

describe "routes for FlavorController" do
  let(:controller_name) { "flavor" }

  it_behaves_like "A controller that has advanced search routes"
  it_behaves_like "A controller that has column width routes"
  it_behaves_like "A controller that has compare routes"
  it_behaves_like "A controller that has download_data routes"
  it_behaves_like "A controller that has tagging routes"

  describe "#button" do
    it "routes" do
      expect(post("/flavor/button/123")).to route_to("flavor#button", :id => "123")
    end
  end

  describe "#index" do
    it "routes" do
      expect(get("/flavor")).to route_to("flavor#index")
    end
  end

  describe "#show" do
    it "routes" do
      expect(get("/flavor/show/123")).to route_to("flavor#show", :id => "123")
    end
  end

  describe "#show_list" do
    it "routes with get" do
      expect(get("/flavor/show_list")).to route_to("flavor#show_list")
    end

    it "routes with post" do
      expect(post("/flavor/show_list")).to route_to("flavor#show_list")
    end
  end

  describe "#sections_field_changed" do
    it "routes with POST" do
      expect(post("/flavor/sections_field_changed")).to route_to(
        "flavor#sections_field_changed"
      )
    end
  end
end
