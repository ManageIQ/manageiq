describe OrchestrationStackHelper::TextualSummary do
  before { @record = FactoryGirl.build(:orchestration_stack) }

  it "#textual_group_lifecycle includes retirement_date" do
    expect(textual_group_lifecycle).to eq([:retirement_date])
  end

  describe "#textual_retirement_date value" do
    it "with no :retires_on returns 'Never'" do
      expect(textual_retirement_date[:value]).to eq("Never")
    end

    it "with :retires_on returns date in %x %R %Z format" do
      @record.retires_on = Date.new(2015, 11, 01).in_time_zone('UTC')
      expect(textual_retirement_date[:value]).to eq("11/01/15 00:00 UTC")
    end
  end
end
