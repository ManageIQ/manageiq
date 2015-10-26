require "spec_helper"
require "routing/shared_examples"

describe OntapStorageVolumeController do
  let(:controller_name) { "ontap_storage_volume" }

  it_behaves_like "A controller that has advanced search routes"
  it_behaves_like "A controller that has compare routes"
  it_behaves_like "A controller that has show list routes"
  it_behaves_like "A controller that has download_data routes"
  it_behaves_like "A controller that has policy protect routes"
  it_behaves_like "A controller that has tagging routes"

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
end
