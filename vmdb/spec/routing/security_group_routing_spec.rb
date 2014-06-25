require "spec_helper"
require "routing/shared_examples"

describe "routing for SecurityGroupController" do
  let(:controller_name) { "security_group" }

  it_behaves_like "A controller that has advanced search routes"
  it_behaves_like "A controller that has column width routes"
  it_behaves_like "A controller that has compare routes"
  it_behaves_like "A controller that has tagging routes"

  describe "no action" do
    it "routes" do
      expect(get("/security_group")).to route_to("security_group#index")
    end
  end

  describe "#button" do
    it "routes" do
      expect(post("/security_group/button")).to route_to("security_group#button")
    end
  end

  describe "#index" do
    it "routes" do
      expect(get("/security_group/index")).to route_to("security_group#index")
    end
  end

  describe "#show" do
    it "routes" do
      expect(get("/security_group/show/123")).to route_to("security_group#show", :id => "123")
    end
  end

  describe "#show_list" do
    it "routes with get" do
      expect(get("/security_group/show_list")).to route_to("security_group#show_list")
    end

    it "routes with post" do
      expect(get("/security_group/show_list")).to route_to("security_group#show_list")
    end
  end
end
