require "spec_helper"

describe MiqProductFeature do
  before do
    @expected_feature_count = 862
  end

  context ".seed" do
    it "creates feature identifiers once on first seed, changes nothing on second seed" do
      status_seed1 = MiqProductFeature.seed
      expect(MiqProductFeature.count).to eq(@expected_feature_count)
      expect(status_seed1[:created]).to match_array status_seed1[:created].uniq
      expect(status_seed1[:updated]).to match_array []
      expect(status_seed1[:unchanged]).to match_array []

      status_seed2 = MiqProductFeature.seed
      MiqProductFeature.count.should eq(@expected_feature_count)
      expect(status_seed2[:created]).to match_array []
      expect(status_seed2[:updated]).to match_array []
      expect(status_seed2[:unchanged]).to match_array status_seed1[:created]
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
