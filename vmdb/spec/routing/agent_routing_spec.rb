require 'spec_helper'

describe 'routes for AgentController' do
  describe "#get" do
    it "routes with GET" do
      expect(get("/agent/get")).to route_to("agent#get")
    end
  end

  describe "#log" do
    it "routes with POST" do
      expect(post("/agent/log")).to route_to("agent#log")
    end
  end
end
