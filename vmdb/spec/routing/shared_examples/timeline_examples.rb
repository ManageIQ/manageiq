shared_examples_for "A controller that has timeline routes" do
  describe "#tl_chooser" do
    it "routes with POST" do
      expect(post("/#{controller_name}/tl_chooser/123")).to route_to("#{controller_name}#tl_chooser", :id => "123")
    end
  end

  describe "#wait_for_task" do
    it "routes with POST" do
      expect(post("/#{controller_name}/wait_for_task")).to route_to("#{controller_name}#wait_for_task")
    end
  end
end
