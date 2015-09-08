require "spec_helper"

describe MiqProductFeature do
  before(:all) do
    MiqRegion.seed
    MiqProductFeature.seed
    @expected_feature_count = MiqProductFeature.count
    MiqProductFeature.destroy_all
  end

  context ".seed" do
    it "sanity" do
      @expected_feature_count.should_not eq(0)
    end

    it "run twice" do
      MiqRegion.seed
      MiqProductFeature.seed
      MiqProductFeature.seed
      MiqProductFeature.count.should eq(@expected_feature_count)
    end

    it "with existing records" do
      deleted   = FactoryGirl.create(:miq_product_feature, :identifier => "xxx")
      changed   = FactoryGirl.create(:miq_product_feature, :identifier => "about", :name => "XXX")
      unchanged = FactoryGirl.create(:miq_product_feature_everything)
      unchanged_orig_updated_at = unchanged.updated_at

      MiqRegion.seed
      MiqProductFeature.seed
      MiqProductFeature.count.should eq(@expected_feature_count)
      expect { deleted.reload }.to raise_error(ActiveRecord::RecordNotFound)
      changed.reload.name.should == "About"
      unchanged.reload.updated_at.should be_same_time_as unchanged_orig_updated_at
    end
  end
end
