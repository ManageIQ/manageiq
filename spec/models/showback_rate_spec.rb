describe ShowbackRate do
  context "validations" do
    let(:showback_rate) { FactoryGirl.build(:showback_rate) }

    it "has a valid factory" do
      expect(showback_rate).to be_valid
    end

    it "should ensure presence of fixed_cost" do
      showback_rate.fixed_cost = nil
      showback_rate.valid?
      expect(showback_rate.errors[:fixed_cost]).to include "can't be blank"
    end

    it "should ensure presence of variable_cost" do
      showback_rate.variable_cost = nil
      showback_rate.valid?
      expect(showback_rate.errors[:variable_cost]).to include "can't be blank"
    end

    it "should ensure presence of concept" do
      showback_rate.concept = nil
      showback_rate.valid?
      expect(showback_rate.errors[:concept]).to include "can't be blank"
    end

    it "variable_cost expected to be BigDeciaml" do
      expect(FactoryGirl.create(:showback_rate, :variable_cost => BigDecimal.new("2.5634525342534"))).to be_valid
    end

    it "fixed_cost expected to be BigDeciaml" do
      expect(FactoryGirl.create(:showback_rate, :fixed_cost => BigDecimal.new("67.4525342534"))).to be_valid
    end
  end
end
