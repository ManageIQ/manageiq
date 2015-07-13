require "spec_helper"

describe "routes for AvailabilityZoneController" do
  let(:controller_name) { "support" }

  describe "#index" do
    it "routes with GET" do
      expect(get("/#{controller_name}")).to route_to("#{controller_name}#index")
    end
  end
end
