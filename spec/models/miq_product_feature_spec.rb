require "spec_helper"

describe MiqProductFeature do
  before do
    @expected_feature_count = 867
  end

  context ".seed" do
    it "empty table" do
      MiqProductFeature.seed
      MiqProductFeature.count.should eq(@expected_feature_count)
    end

    it "run twice" do
      MiqProductFeature.seed
      MiqProductFeature.seed
      MiqProductFeature.count.should eq(@expected_feature_count)
    end

    it "with existing records" do
      deleted   = FactoryGirl.create(:miq_product_feature, :identifier => "xxx")
      changed   = FactoryGirl.create(:miq_product_feature, :identifier => "about", :name => "XXX")
      unchanged = FactoryGirl.create(:miq_product_feature_everything)
      unchanged_orig_updated_at = unchanged.updated_at

      MiqProductFeature.seed
      MiqProductFeature.count.should eq(@expected_feature_count)
      expect { deleted.reload }.to raise_error(ActiveRecord::RecordNotFound)
      changed.reload.name.should == "About"
      unchanged.reload.updated_at.should be_same_time_as unchanged_orig_updated_at
    end
  end
end
