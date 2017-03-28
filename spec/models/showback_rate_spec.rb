describe ShowbackRate do
  context "validations" do
    let(:showback_rate) { FactoryGirl.build(:showback_rate) }

    it "has a valid factory" do
      expect(showback_rate).to be_valid
    end

    it "is not valid with a nil fixed_cost" do
      showback_rate.fixed_cost = nil
      showback_rate.valid?
      expect(showback_rate.errors.details[:fixed_cost]).to include({:error=>:blank})
    end

    it "is not valid with a nil variable_cost" do
      showback_rate.variable_cost = nil
      showback_rate.valid?
      expect(showback_rate.errors.details[:variable_cost]).to include({:error=>:blank})
    end

    it "is  valid with a nil concept" do
      showback_rate.concept = nil
      showback_rate.valid?
      expect(showback_rate).to be_valid
    end

    it "is not valid with a nil calculation" do
      showback_rate.calculation = nil
      showback_rate.valid?
      expect(showback_rate.errors.details[:calculation]).to include({:error=>:blank})
    end

    it "is is valid with a nil concept" do
      showback_rate.concept = nil
      showback_rate.valid?
      expect(showback_rate).to be_valid
    end

    it "is not valid with a nil dimension" do
      showback_rate.dimension = nil
      showback_rate.valid?
      expect(showback_rate.errors.details[:dimension]).to include({:error=>:blank})
    end

    it "variable_cost expected to be BigDeciaml" do
      expect(FactoryGirl.create(:showback_rate, :variable_cost => BigDecimal.new("2.5634525342534"))).to be_valid
    end

    it "fixed_cost expected to be BigDeciaml" do
      expect(FactoryGirl.create(:showback_rate, :fixed_cost => BigDecimal.new("67.4525342534"))).to be_valid
    end
  end
end
