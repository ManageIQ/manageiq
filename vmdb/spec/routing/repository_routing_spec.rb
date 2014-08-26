require "spec_helper"
require "routing/shared_examples"

describe "routes for AvailabilityZoneController" do
  let(:controller_name) { "repository" }

  it_behaves_like "A controller that has advanced search routes"
  it_behaves_like "A controller that has column width routes"
  it_behaves_like "A controller that has compare routes"
  it_behaves_like "A controller that has download_data routes"
  it_behaves_like "A controller that has policy protect routes"
  it_behaves_like "A controller that has show list routes"
  it_behaves_like "A controller that has CRUD routes"

  describe "#button" do
    it "routes with POST" do
      expect(post("/repository/button")).to route_to("repository#button")
    end
  end

  describe "#form_field_changed" do
    it "routes with POST" do
      expect(post("/repository/form_field_changed"))
      .to route_to("repository#form_field_changed")
    end
  end

  describe "#listnav_search_selected" do
    it "routes with POST" do
      expect(post("/repository/listnav_search_selected"))
      .to route_to("repository#listnav_search_selected")
    end
  end

  describe "#save_default_search" do
    it "routes with POST" do
      expect(post("/repository/save_default_search"))
      .to route_to("repository#save_default_search")
    end
  end

  describe "#show" do
    it "routes with GET" do
      expect(get("/repository/show")).to route_to("repository#show")
    end

    it "routes with POST" do
      expect(post("/repository/show")).to route_to("repository#show")
    end
  end

end
