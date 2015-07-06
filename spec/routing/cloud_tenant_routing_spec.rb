require "spec_helper"
require "routing/shared_examples"

describe EmsCloudController do
  let(:controller_name) { "ems_cloud" }

  it_behaves_like "A controller that has column width routes"
  it_behaves_like "A controller that has compare routes"
  it_behaves_like "A controller that has tagging routes"

  describe "#button" do
    it "routes with POST" do
      expect(post("/cloud_tenant/button")).to route_to("cloud_tenant#button")
    end
  end

  describe "#sections_field_changed" do
    it "routes with POST" do
      expect(post("/cloud_tenant/sections_field_changed")).to route_to("cloud_tenant#sections_field_changed")
    end
  end

  describe "#show_list" do
    it "routes with GET" do
      expect(get("/cloud_tenant/show_list")).to route_to("cloud_tenant#show_list")
    end

    it "routes with POST" do
      expect(post("/cloud_tenant/show_list")).to route_to("cloud_tenant#show_list")
    end
  end

  describe "#download_data" do
    it "routes with GET" do
      expect(get("/cloud_tenant/download_data")).to route_to("cloud_tenant#download_data")
    end
  end
end
