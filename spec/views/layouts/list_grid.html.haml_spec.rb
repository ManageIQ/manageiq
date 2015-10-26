require "spec_helper"

describe "layouts/_list_grid.html.haml" do
  context "when showtype is 'performance'" do
    it "renders" do
      view.stub(:options).and_return({})
      view.stub(:js_options).and_return({})
      record = EmsInfra.new(:id => 1)
      assign(:parent, record)
      render
    end
  end
end
