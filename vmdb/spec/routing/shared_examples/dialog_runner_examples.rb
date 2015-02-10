shared_examples_for "A controller that has dialog runner routes" do
  %w(
    dialog_field_changed
    dialog_form_button_pressed
    dynamic_checkbox_refresh
    dynamic_list_refresh
    dynamic_radio_button_refresh
    dynamic_text_box_refresh
  ).each do |path|
    describe "##{path}" do
      it "routes with POST" do
        expect(post("/#{controller_name}/#{path}")).to route_to("#{controller_name}##{path}")
      end
    end
  end
end
