require "spec_helper"
describe ConfigurationHelper, :helper do
  [[:compare, "compressed", 1],
   [:compare, "expanded", 1],
   [:tagging, "tile", 2]].each do |resource, view, inactive_icon_count|
    context ".render_view_buttons" do
      it "should render HTML tags for #{resource} view button" do
        helper.stub(:link_to)   { "inactive_icon" }
        icons = helper.render_view_buttons(resource, view)
        icons.scan(/inactive_icon/).length.should eql(inactive_icon_count)
      end
    end
  end
end
