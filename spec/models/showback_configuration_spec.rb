describe ShowbackConfiguration do
  before do
    @expected_showback_configuration_count = 4
  end

  context "validations" do
    let(:showback) { FactoryGirl.build(:showback_configuration) }

    it "has a valid factory" do
      expect(showback).to be_valid
    end
    it "should ensure presence of name" do
      showback.name = nil
      showback.valid?
      expect(showback.errors[:name]).to include "can't be blank"
    end

    it "should ensure presence of description" do
      showback.description = nil
      showback.valid?
      expect(showback.errors[:description]).to include "can't be blank"
    end

    it "should ensure presence of measure type" do
      showback.measure = nil
      showback.valid?
      expect(showback.errors[:measure]).to include "is not included in the list"
    end

    it "should invalidate incorrect measure type" do
      showback.measure = "AA"
      showback.valid?
      expect(showback.errors[:measure]).to include "is not included in the list"
    end

    it "should validate correct measure type" do
      showback.measure = "Integer"
      expect(showback).to be_valid
    end

    it "should ensure presence of types" do
      showback.types = []
      showback.valid?
      expect(showback.errors[:types]).to include "can't be blank"
    end
  end

  context ".seed" do
    it "empty table" do
      ShowbackConfiguration.seed
      expect(ShowbackConfiguration.count).to eq(@expected_showback_configuration_count)
    end

    it "run twice" do
      ShowbackConfiguration.seed
      ShowbackConfiguration.seed
      expect(ShowbackConfiguration.count).to eq(@expected_showback_configuration_count)
    end

    it "with existing records" do
      unchanged = FactoryGirl.create(:showback_configuration, :name => "xxx")
      unchanged_orig_updated_at = unchanged.updated_at

      ShowbackConfiguration.seed

      expect(ShowbackConfiguration.count).to eq(@expected_showback_configuration_count + 1)
      expect(unchanged.reload.updated_at).to be_same_time_as unchanged_orig_updated_at
    end
  end
end
