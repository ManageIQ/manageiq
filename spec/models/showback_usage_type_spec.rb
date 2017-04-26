describe ShowbackUsageType do
  before do
    @expected_showback_usage_type_count = 1
  end

  context "validations" do
    let(:showback_usage) { FactoryGirl.build(:showback_usage_type) }

    it "has a valid factory" do
      expect(showback_usage).to be_valid
    end
    it "should ensure presence of category" do
      showback_usage.category = nil
      showback_usage.valid?
      expect(showback_usage.errors[:category]).to include "is not included in the list"
    end

    it "should ensure presence of category included in VALID_CATEGORY fail" do
      showback_usage.category = "region"
      showback_usage.valid?
      expect(showback_usage.errors[:category]).to include "is not included in the list"
    end

    it "should ensure presence of description" do
      showback_usage.description = nil
      showback_usage.valid?
      expect(showback_usage.errors[:description]).to include "can't be blank"
    end

    it "should ensure presence of usage type" do
      showback_usage.measure = nil
      showback_usage.valid?
      expect(showback_usage.errors[:measure]).to include "is not included in the list"
    end

    it "should invalidate incorrect usage type" do
      showback_usage.measure = "AA"
      showback_usage.valid?
      expect(showback_usage.errors[:measure]).to include "is not included in the list"
    end

    it "should validate correct usage type" do
      showback_usage.measure = "CPU"
      expect(showback_usage).to be_valid
    end

    it "should ensure presence of dimensions" do
      showback_usage.dimensions = []
      showback_usage.valid?
      expect(showback_usage.errors[:dimensions]).to include "can't be blank"
    end

    it "should ensure presence of dimensions included in VALID_TYPES" do
      showback_usage.dimensions = %w(average number)
      expect(showback_usage).to be_valid
    end

    it "should ensure presence of dimensions included in VALID_TYPES fail" do
      showback_usage.dimensions = %w(counted number)
      showback_usage.valid?
      expect(showback_usage.errors[:dimensions]).to include "counted is not a valid measure dimension"
    end
  end

  context ".seed" do
    it "empty table" do
      ShowbackUsageType.seed
      expect(ShowbackUsageType.count).to eq(@expected_showback_usage_type_count)
    end

    it "run twice" do
      ShowbackUsageType.seed
      ShowbackUsageType.seed
      expect(ShowbackUsageType.count).to eq(@expected_showback_usage_type_count)
    end
  end
end
