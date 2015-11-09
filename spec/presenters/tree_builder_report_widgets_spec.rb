require "spec_helper"

describe TreeBuilderReportWidgets do
  it "#x_get_tree_custom_kids" do
    widget1 = FactoryGirl.create(:miq_widget)
    widget2 = FactoryGirl.create(:miq_widget)
    FactoryGirl.create(:miq_widget, :content_type => "menu")

    tree = described_class.new("cb_rates_tree", "cb_rates", {}).send(:x_get_tree_custom_kids, {:id => "-r"}, false, nil)
    expect(tree).to match_array([widget1, widget2])
  end
end
