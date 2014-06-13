shared_examples_for "A controller that has download_data routes" do
  describe "#download_data" do
    it "routes with GET" do
      expect(get("/#{controller_name}/download_data")).to route_to("#{controller_name}#download_data")
    end
  end
end
