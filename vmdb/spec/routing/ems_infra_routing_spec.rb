require "spec_helper"
require "routing/shared_examples"

describe EmsInfraController do
  let(:controller_name) { "ems_infra" }

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
      expect(post("/ems_infra/button")).to route_to("ems_infra#button")
    end
  end

  describe "#form_field_changed" do
    it "routes with POST" do
      expect(post("/ems_infra/form_field_changed")).to route_to("ems_infra#form_field_changed")
    end
  end

  describe "#new" do
    it "routes with GET" do
      expect(get("/ems_infra/new")).to route_to("ems_infra#new")
    end
  end

  describe "#sections_field_changed" do
    it "routes with POST" do
      expect(post("/ems_infra/sections_field_changed")).to route_to("ems_infra#sections_field_changed")
    end
  end

  describe "#show_list" do
    it "routes with GET" do
      expect(get("/ems_infra/show_list")).to route_to("ems_infra#show_list")
    end

    it "routes with POST" do
      expect(post("/ems_infra/show_list")).to route_to("ems_infra#show_list")
    end
  end

  describe "#tree_autoload_dynatree" do
    it "routes with POST" do
      expect(post("/ems_infra/tree_autoload_dynatree")).to route_to("ems_infra#tree_autoload_dynatree")
    end
  end

  describe "#tree_autoload_quads" do
    it "routes with POST" do
      expect(post("/ems_infra/tree_autoload_quads")).to route_to("ems_infra#tree_autoload_quads")
    end
  end
end
