require "spec_helper"

describe TreeBuilderReportWidgets do
  subject { described_class.new("cb_rates_tree", "cb_rates", {}) }

  it "#set_locals_for_render (private)" do
    expect(subject.send(:set_locals_for_render)).to have_attributes(:id_prefix => 'widgets_', :autoload => true)
  end

  it "#x_get_tree_roots (private)" do
    expect(subject.send(:x_get_tree_roots, false, nil)).to match_array([
      {:id => "r",  :text => "Reports",   :image => "folder", :tip => "Reports"},
      {:id => "c",  :text => "Charts",    :image => "folder", :tip => "Charts"},
      {:id => "rf", :text => "RSS Feeds", :image => "folder", :tip => "RSS Feeds"},
      {:id => "m",  :text => "Menus",     :image => "folder", :tip => "Menus"}
    ])
  end

  it "#x_get_tree_custom_kids (private)" do
    widget1 = FactoryGirl.create(:miq_widget)
    widget2 = FactoryGirl.create(:miq_widget)
    FactoryGirl.create(:miq_widget, :content_type => "menu")

    expect(subject.send(:x_get_tree_custom_kids, {:id => "-r"}, false, nil)).to match_array([widget1, widget2])
  end
end
