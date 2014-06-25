require "spec_helper"
require "routing/shared_examples"

describe "routes for AvailabilityZoneController" do
  let(:controller_name) { "resource_pool" }

  it_behaves_like "A controller that has advanced search routes"
  it_behaves_like "A controller that has column width routes"
  it_behaves_like "A controller that has download_data routes"
  it_behaves_like "A controller that has show list routes"
  it_behaves_like "A controller that has tagging routes"
  it_behaves_like "A controller that has policy protect routes"

  describe "#index" do
    it "routes with GET" do
      expect(get("/#{controller_name}")).to route_to("#{controller_name}#index")
    end
  end

  describe "#show" do
    it "routes with GET" do
      expect(get("/#{controller_name}/show/123")).to route_to("#{controller_name}#show", :id => "123")
    end
    it "routes with POST" do
      expect(post("/#{controller_name}/show/123")).to route_to("#{controller_name}#show", :id => "123")
    end
  end

  describe "#button" do
    it "routes with POST" do
      expect(post("/#{controller_name}/button")).to route_to("#{controller_name}#button")
    end
  end
end
