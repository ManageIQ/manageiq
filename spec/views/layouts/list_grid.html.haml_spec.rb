require "spec_helper"

describe "layouts/_list_grid.html.haml" do
  context "when showtype is 'performance'" do
    it "renders" do
      view.stub(:options).and_return({:grid_hash => {:head => [], :rows => []}})
      view.stub(:js_options).and_return({:row_url => '_none_'})
      record = EmsInfra.new(:id => 1)
      assign(:parent, record)
      render
    end
  end
end
