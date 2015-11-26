require "spec_helper"

describe "report/_db_widget_remove.html.haml" do
  before do
    ws = FactoryGirl.create(:miq_widget_set)
    assign(:db, ws)
  end

  it "correctly renders patternfly classes" do
    widget = FactoryGirl.create(:miq_widget)
    render :partial => "report/db_widget_remove",
           :locals  => {:widget => widget}
    response.should have_selector('a.pull-right')
    response.should have_selector('i.fa.fa-remove')
  end
end
