shared_examples_for "A controller that has utilization routes" do
  describe "#util_chart_chooser" do
    it "routes with POST" do
      expect(post("/#{controller_name}/util_chart_chooser")).to route_to("#{controller_name}#util_chart_chooser")
    end
  end

  describe "#util_report_download" do
    it "routes with GET" do
      expect(get("/#{controller_name}/util_report_download")).to route_to("#{controller_name}#util_report_download")
    end
  end

  describe "#utilization" do
    it "routes with GET" do
      expect(get("/#{controller_name}/utilization")).to route_to("#{controller_name}#utilization")
    end
  end
end
