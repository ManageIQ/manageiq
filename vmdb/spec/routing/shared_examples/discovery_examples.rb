shared_examples_for "A controller that has discovery routes" do
  describe "#discover" do
    it "routes with GET" do
      expect(get("/#{controller_name}/discover")).to route_to("#{controller_name}#discover")
    end

    it "routes with POST" do
      expect(post("/#{controller_name}/discover")).to route_to("#{controller_name}#discover")
    end
  end

  describe "#discover_field_changed" do
    it "routes with POST" do
      expect(post("/#{controller_name}/discover_field_changed")).to route_to("#{controller_name}#discover_field_changed")
    end
  end
end
