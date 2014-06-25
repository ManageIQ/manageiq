shared_examples_for "A controller that has column width routes" do
  describe "#save_col_widths" do
    it "routes with POST" do
      expect(post("/#{controller_name}/save_col_widths")).to route_to("#{controller_name}#save_col_widths")
    end
  end
end
