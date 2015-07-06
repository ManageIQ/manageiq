require 'spec_helper'

describe "routes for VmdbwsController" do
  describe "#api" do
    it "routes with POST" do
      expect(post("/vmdbws/api")).to route_to("vmdbws#api")
    end
  end

  describe "#wsdl" do
    it "routes with GET" do
      expect(get("/vmdbws/wsdl")).to route_to("vmdbws#wsdl")
    end
  end
end
