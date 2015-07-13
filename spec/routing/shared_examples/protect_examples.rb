shared_examples_for "A controller that has policy protect routes" do
  describe "#protect" do
    it "routes with GET" do
      expect(get("/#{controller_name}/protect")).to route_to("#{controller_name}#protect")
    end

    it "routes with POST" do
      expect(post("/#{controller_name}/protect")).to route_to("#{controller_name}#protect")
    end
  end
end
