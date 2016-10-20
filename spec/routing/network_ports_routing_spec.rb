describe "routes for Network Ports" do
  let(:controller_name) { "network_port" }
  describe "#listnav_search_selected" do
    it "routes with POST" do
      expect(post("/#{controller_name}/listnav_search_selected")).to route_to(
        "#{controller_name}#listnav_search_selected")
    end
  end

  describe "#save_default_search" do
    it "routes with POST" do
      expect(post("/#{controller_name}/save_default_search")).to route_to(
        "#{controller_name}#save_default_search")
    end
  end
end
