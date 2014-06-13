shared_examples_for "A controller that has show list routes" do
  describe "#show_list" do
    it "routes with GET" do
      expect(get("/#{controller_name}/show_list")).to route_to("#{controller_name}#show_list")
    end

    it "routes with POST" do
      expect(post("/#{controller_name}/show_list")).to route_to("#{controller_name}#show_list")
    end
  end
end
