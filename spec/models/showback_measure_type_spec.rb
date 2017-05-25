describe ShowbackMeasureType do
  before do
    @expected_showback_measure_type_count = 1
  end

  context "validations" do
    let(:showback_measure) { FactoryGirl.build(:showback_measure_type) }

    it "has a valid factory" do
      expect(showback_measure).to be_valid
    end
    it "should ensure presence of name" do
      showback_measure.name = nil
      showback_measure.valid?
      expect(showback_measure.errors[:name]).to include "can't be blank"
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

    it "should ensure presence of types" do
      showback_measure.types = []
      showback_measure.valid?
      expect(showback_measure.errors[:types]).to include "can't be blank"
    end

    it "should ensure presence of types included in VALID_TYPES" do
      showback_measure.types = ["average", "number"]
      expect(showback_measure).to be_valid
    end

    it "should ensure presence of types included in VALID_TYPES fail" do
      showback_measure.types = ["counted", "number"]
      showback_measure.valid?
      expect(showback_measure.errors[:types]).to include "is not a valid measure type"
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

    it "with existing records" do
      unchanged = FactoryGirl.create(:showback_measure_type, :name => "xxx")
      unchanged_orig_updated_at = unchanged.updated_at

      ShowbackMeasureType.seed

      expect(ShowbackMeasureType.count).to eq(@expected_showback_measure_type_count + 1)
      expect(unchanged.reload.updated_at).to be_same_time_as unchanged_orig_updated_at
    end
  end
end
