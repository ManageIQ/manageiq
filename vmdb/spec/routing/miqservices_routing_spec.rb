require 'spec_helper'

describe "routes for MiqservicesController" do
  describe "#api" do
    it "routes with POST" do
      expect(post("/miqservices/api")).to route_to("miqservices#api")
    end
  end
end
