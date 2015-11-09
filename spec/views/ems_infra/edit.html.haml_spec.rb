require "spec_helper"

describe "ems_infra/edit.html.haml" do
  let(:ems_infra) { FactoryGirl.create(:ems_infra) }

  before(:each) do
    assign(:ems, ems_infra)
  end

  context "when ems_type is rhevm" do
    before(:each) do
      @edit = {:new          => {:emstype => 'rhevm'},
               :ems_types    => {:a => 'a', :b => 'b'},
               :server_zones => []}
    end

    it "renders API Port input field for RHEV-M" do
      render
      expect(rendered).to match(/API\ Port/)
    end
  end
end
