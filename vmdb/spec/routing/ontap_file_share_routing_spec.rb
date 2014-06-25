require "spec_helper"
require "routing/shared_examples"

describe OntapFileShareController do
  let(:controller_name) { "ontap_file_share" }

  it_behaves_like "A controller that has advanced search routes"
  it_behaves_like "A controller that has column width routes"
  it_behaves_like "A controller that has compare routes"
  it_behaves_like "A controller that has show list routes"
  it_behaves_like "A controller that has download_data routes"
  it_behaves_like "A controller that has tagging routes"

  describe "#button" do
    it "routes with POST" do
      expect(post("/#{controller_name}/button")).to route_to("#{controller_name}#button")
    end
  end

  describe "#cim_base_storage_extents" do
    it "routes with GET" do
      expect(get("/#{controller_name}/cim_base_storage_extents")).to route_to(
        "#{controller_name}#cim_base_storage_extents")
    end
  end

  describe "#create_ds" do
    it "routes with GET" do
      expect(get("/#{controller_name}/create_ds")).to route_to("#{controller_name}#create_ds")
    end

    it "routes with POST" do
      expect(post("/#{controller_name}/create_ds")).to route_to("#{controller_name}#create_ds")
    end
  end

  describe "#create_ds_field_changed" do
    it "routes with POST" do
      expect(post("/#{controller_name}/create_ds_field_changed")).to route_to(
        "#{controller_name}#create_ds_field_changed")
    end
  end

  describe "#protect" do
    it "routes with GET" do
      expect(get("/#{controller_name}/protect")).to route_to("#{controller_name}#protect")
    end

    it "routes with POST" do
      expect(post("/#{controller_name}/protect")).to route_to("#{controller_name}#protect")
    end
  end

  describe "#snia_local_file_systems" do
    it "routes with GET" do
      expect(get("/#{controller_name}/snia_local_file_systems")).to route_to(
        "#{controller_name}#snia_local_file_systems")
    end
  end
end
