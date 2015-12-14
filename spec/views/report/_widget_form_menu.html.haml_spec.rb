require "spec_helper"

describe "report/_widget_form_menu.html.haml" do
  before do
    w = FactoryGirl.create(:miq_widget)
    assign(:widget, w)
    assign(:edit, :avail_shortcuts => %w(xx yy), :read_only => 0, :new => {:shortcuts => %w(id desc)})
  end

  it "correctly renders patternfly classes" do
    render
    response.should have_selector('a.fa.fa-close.pull-right')
  end
end
