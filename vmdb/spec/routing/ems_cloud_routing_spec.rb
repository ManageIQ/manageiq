require "spec_helper"
require "routing/shared_examples"

describe EmsCloudController do
  let(:controller_name) { "ems_cloud" }

  it_behaves_like "A controller that has advanced search routes"
  it_behaves_like "A controller that has column width routes"
  it_behaves_like "A controller that has compare routes"
  it_behaves_like "A controller that has CRUD routes"
  it_behaves_like "A controller that has discovery routes"
  it_behaves_like "A controller that has download_data routes"
  it_behaves_like "A controller that has policy protect routes"
  it_behaves_like "A controller that has tagging routes"
  it_behaves_like "A controller that has timeline routes"

  describe "#button" do
    it "routes with POST" do
      expect(post("/ems_cloud/button")).to route_to("ems_cloud#button")
    end
  end

  describe "#dynamic_list_refresh" do
    it "routes with POST" do
      expect(post("/ems_cloud/dynamic_list_refresh")).to route_to("ems_cloud#dynamic_list_refresh")
    end
  end

  describe "#form_field_changed" do
    it "routes with POST" do
      expect(post("/ems_cloud/form_field_changed")).to route_to("ems_cloud#form_field_changed")
    end
  end

  describe "#new" do
    it "routes with GET" do
      expect(get("/ems_cloud/new")).to route_to("ems_cloud#new")
    end
  end

  describe "#sections_field_changed" do
    it "routes with POST" do
      expect(post("/ems_cloud/sections_field_changed")).to route_to("ems_cloud#sections_field_changed")
    end
  end

  describe "#show_list" do
    it "routes with GET" do
      expect(get("/ems_cloud/show_list")).to route_to("ems_cloud#show_list")
    end

    it "routes with POST" do
      expect(post("/ems_cloud/show_list")).to route_to("ems_cloud#show_list")
    end
  end
end
