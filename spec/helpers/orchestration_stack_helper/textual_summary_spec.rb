require "spec_helper"

describe OrchestrationStackHelper::TextualSummary do
  before :each do
    @record = FactoryGirl.create(:orchestration_stack)
  end

  it "#textual_group_lifecycle should includes retirement_date" do
    expect(self.textual_group_lifecycle).to include(:retirement_date)
  end

  describe "#textual_retirement_date" do
    it "should returns 'Never' if nil values is passed" do
      @record.retires_on = nil
      expect(self.textual_retirement_date).to include(:value => "Never")
    end

    it "should returns date in %x format" do
      @record.retires_on = Date.new(2015, 11, 01)
      expect(self.textual_retirement_date).to include(:value => "11/01/15")
    end
  end
end
