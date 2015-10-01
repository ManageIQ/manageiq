require "spec_helper"

describe "layouts/_dhtmlxgrid.html.haml" do
  context "when showtype is 'performance'" do
    it "renders" do
      view.stub(:options).and_return({})
      record = EmsInfra.new(:id => 1)
      assign(:parent, record)
      render
    end
  end
end
