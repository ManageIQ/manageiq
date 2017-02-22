describe ShowbackConfiguration do
  before do
    @expected_showback_configuration_count = 4
  end

  context "validations" do
    it "should ensure presence of name" do
      expect(FactoryGirl.build(:showback_configuration, :name => nil)).not_to be_valid
    end

    it "should ensure presence of description" do
      expect(FactoryGirl.build(:showback_configuration, :description => nil)).not_to be_valid
    end

    it "should ensure presence of measure type" do
      expect(FactoryGirl.build(:showback_configuration, :measure => nil)).not_to be_valid
    end

    it "should invalidate incorrect measure type" do
      expect(FactoryGirl.build(:showback_configuration, :measure => "AA")).not_to be_valid
    end

    it "should validate correct measure type" do
      expect(FactoryGirl.build(:showback_configuration, :measure => "Integer")).to be_valid
    end

    it "should ensure presence of types" do
      expect(FactoryGirl.build(:showback_configuration, :types => [])).not_to be_valid
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
