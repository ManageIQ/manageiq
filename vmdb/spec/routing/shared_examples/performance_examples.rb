shared_examples_for "A controller that has performance routes" do
  describe "#perf_chart_chooser" do
    it "routes with GET" do
      expect(get("/#{controller_name}/perf_chart_chooser")).to route_to("#{controller_name}#perf_chart_chooser")
    end

    it "routes with POST" do
      expect(post("/#{controller_name}/perf_chart_chooser")).to route_to("#{controller_name}#perf_chart_chooser")
    end
  end

  describe "#wait_for_task" do
    it "routes with POST" do
      expect(post("/#{controller_name}/wait_for_task")).to route_to("#{controller_name}#wait_for_task")
    end
  end
end
