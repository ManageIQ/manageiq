require "spec_helper"
require "routing/shared_examples"

describe OntapStorageSystemController do
  let(:controller_name) { "ontap_storage_system" }

  it_behaves_like "A controller that has advanced search routes"
  it_behaves_like "A controller that has compare routes"
  it_behaves_like "A controller that has show list routes"
  it_behaves_like "A controller that has download_data routes"
  it_behaves_like "A controller that has tagging routes"
  it_behaves_like "A controller that has policy protect routes"

  describe "#button" do
    it "routes with POST" do
      expect(post("/#{controller_name}/button")).to route_to("#{controller_name}#button")
    end
  end

  describe "#create_ld" do
    it "routes with GET" do
      expect(post("/#{controller_name}/create_ld")).to route_to("#{controller_name}#create_ld")
    end
    it "routes with POST" do
      expect(post("/#{controller_name}/create_ld")).to route_to("#{controller_name}#create_ld")
    end
  end

  describe "#create_ld_field_changed" do
    it "routes with POST" do
      expect(post("/#{controller_name}/create_ld_field_changed")).to route_to(
        "#{controller_name}#create_ld_field_changed")
    end
  end

  describe "#cim_base_storage_extents" do
    it "routes with GET" do
      expect(get("/#{controller_name}/cim_base_storage_extents")).to route_to(
        "#{controller_name}#cim_base_storage_extents")
    end
  end

  describe "#index" do
    it "routes with GET" do
      expect(get("/#{controller_name}/index")).to route_to("#{controller_name}#index")
    end
  end

  describe "#sections_field_changed" do
    it "routes with POST" do
      expect(post("/#{controller_name}/sections_field_changed")).to route_to(
                                                                        "#{controller_name}#sections_field_changed")
    end
  end

  describe "#snia_local_file_systems" do
    it "routes with GET" do
      expect(get("/#{controller_name}/snia_local_file_systems")).to route_to(
        "#{controller_name}#snia_local_file_systems")
    end
  end
end
