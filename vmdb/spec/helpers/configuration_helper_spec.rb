require "spec_helper"
describe ConfigurationHelper, :helper do
  [[:compare, "compressed", 1],
   [:compare, "expanded", 1],
   [:tagging, "tile", 2]].each do |resource, view, inactive_icon_count|
    context ".render_view_buttons" do
      it "should render HTML tags for #{resource} view button" do
        helper.stub(:inactive_icon) { "" }
        helper.render_view_buttons(resource, view)
        helper.should have_received(:inactive_icon).exactly(inactive_icon_count).times
      end
    end
  end
end
