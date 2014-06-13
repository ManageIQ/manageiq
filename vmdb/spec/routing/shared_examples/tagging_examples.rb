shared_examples_for "A controller that has tagging routes" do
  describe "#tagging_edit" do
    it "routes with GET" do
      expect(get("/#{controller_name}/tagging_edit/123")).to route_to(
        "#{controller_name}#tagging_edit", :id => "123"
      )
    end

    it "routes with POST" do
      expect(post("/#{controller_name}/tagging_edit/123")).to route_to(
        "#{controller_name}#tagging_edit", :id => "123"
      )
    end
  end

  describe "#tag_edit_form_field_changed" do
    it "routes with POST" do
      expect(post("/#{controller_name}/tag_edit_form_field_changed/123")).to route_to(
        "#{controller_name}#tag_edit_form_field_changed", :id => "123"
      )
    end
  end

  describe "#toggle_dash" do
    it "routes with POST" do
      expect(post("/#{controller_name}/toggle_dash/123")).to route_to(
        "#{controller_name}#toggle_dash", :id => "123"
      )
    end
  end
end
