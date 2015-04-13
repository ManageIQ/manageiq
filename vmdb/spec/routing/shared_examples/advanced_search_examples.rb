shared_examples_for "A controller that has advanced search routes" do
  describe "#quick_search" do
    it "routes with POST" do
      expect(post("/#{controller_name}/quick_search")).to route_to("#{controller_name}#quick_search")
    end

    it "does not route with GET" do
      expect(get("/#{controller_name}/quick_search")).not_to be_routable
    end
  end

  describe "#panel_control" do
    it "routes with POST" do
      expect(post("/#{controller_name}/panel_control")).to route_to("#{controller_name}#panel_control")
    end
  end
end
