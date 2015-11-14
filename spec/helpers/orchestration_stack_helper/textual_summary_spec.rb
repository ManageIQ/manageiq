require "spec_helper"

describe OrchestrationStackHelper::TextualSummary do
  before { @record = FactoryGirl.build(:orchestration_stack) }

  it "#textual_group_lifecycle should includes retirement_date" do
    expect(textual_group_lifecycle).to include(:retirement_date)
  end

  describe "#textual_retirement_date" do
    it "should returns 'Never' if nil values is passed" do
      expect(textual_retirement_date).to include(:value => "Never")
    end

    it "should returns date in %x format" do
      @record.retires_on = Date.new(2015, 11, 01)
      expect(textual_retirement_date).to include(:value => "11/01/15")
    end
  end
end
