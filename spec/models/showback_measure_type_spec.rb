describe ShowbackMeasureType do
  before do
    @expected_showback_measure_type_count = 1
  end

  context "validations" do
    let(:showback_measure) { FactoryGirl.build(:showback_measure_type) }

    it "has a valid factory" do
      expect(showback_measure).to be_valid
    end
    it "should ensure presence of category" do
      showback_measure.category = nil
      showback_measure.valid?
      expect(showback_measure.errors[:category]).to include "is not included in the list"
    end

    it "should ensure presence of category included in VALID_CATEGORY fail" do
      showback_measure.category = "region"
      showback_measure.valid?
      expect(showback_measure.errors[:category]).to include "is not included in the list"
    end

    it "should ensure presence of description" do
      showback_measure.description = nil
      showback_measure.valid?
      expect(showback_measure.errors[:description]).to include "can't be blank"
    end

    it "should ensure presence of measure type" do
      showback_measure.measure = nil
      showback_measure.valid?
      expect(showback_measure.errors[:measure]).to include "is not included in the list"
    end

    it "should invalidate incorrect measure type" do
      showback_measure.measure = "AA"
      showback_measure.valid?
      expect(showback_measure.errors[:measure]).to include "is not included in the list"
    end

    it "should validate correct measure type" do
      showback_measure.measure = "CPU"
      expect(showback_measure).to be_valid
    end

    it "should ensure presence of dimensions" do
      showback_measure.dimensions = []
      showback_measure.valid?
      expect(showback_measure.errors[:dimensions]).to include "can't be blank"
    end

    it "should ensure presence of dimensions included in VALID_TYPES" do
      showback_measure.dimensions = %w(average number)
      expect(showback_measure).to be_valid
    end

    it "should ensure presence of dimensions included in VALID_TYPES fail" do
      showback_measure.dimensions = %w(counted number)
      showback_measure.valid?
      expect(showback_measure.errors[:dimensions]).to include "counted is not a valid measure dimension"
    end
  end

  context ".seed" do
    it "empty table" do
      ShowbackMeasureType.seed
      expect(ShowbackMeasureType.count).to eq(@expected_showback_measure_type_count)
    end

    it "run twice" do
      ShowbackMeasureType.seed
      ShowbackMeasureType.seed
      expect(ShowbackMeasureType.count).to eq(@expected_showback_measure_type_count)
    end
  end
end
