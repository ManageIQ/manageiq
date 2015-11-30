require "spec_helper"
require 'tmpdir'
require 'pathname'

describe MiqProductFeature do
  before do
    @expected_feature_count = 872
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
  end

  context ".seed_features" do
    let(:feature_path) { Pathname.new(@tempfile.path.sub(/\.yml/, '')) }
    let(:base) do
      {
        :feature_type => "node",
        :identifier   => "everything",
        :children     => [
          {
            :feature_type => "node",
            :identifier   => "one",
            :name         => "One",
            :children     => []
          }
        ]
      }
    end

    before do
      @tempdir  = Dir.mktmpdir
      @tempfile = Tempfile.new(['feature', '.yml'], @tempdir)
      @tempfile.write(YAML.dump(base))
      @tempfile.close
    end

    after do
      @tempfile.unlink
      Dir.rmdir(@tempdir)
    end

    it "existing records" do
      deleted   = FactoryGirl.create(:miq_product_feature, :identifier => "xxx")
      changed   = FactoryGirl.create(:miq_product_feature, :identifier => "one", :name => "XXX")
      unchanged = FactoryGirl.create(:miq_product_feature_everything)
      unchanged_orig_updated_at = unchanged.updated_at

      MiqProductFeature.seed_features(feature_path)
      expect { deleted.reload }.to raise_error(ActiveRecord::RecordNotFound)
      changed.reload.name.should == "One"
      unchanged.reload.updated_at.should be_same_time_as unchanged_orig_updated_at
    end

    it "additional yaml feature" do
      additional = {
        :feature_type => "node",
        :identifier   => "two",
        :children     => []
      }

      Dir.mkdir(feature_path)
      additional_file = Tempfile.new(['additional', '.yml'], feature_path)
      additional_file.write(YAML.dump(additional))
      additional_file.close

      status_seed = MiqProductFeature.seed_features(feature_path)
      MiqProductFeature.count.should eq(3)
      expect(status_seed[:created]).to match_array %w(everything one two)

      additional_file.unlink
      Dir.rmdir(feature_path)
    end
  end

  describe "#feature_details" do
    it "returns data for visible features" do
      EvmSpecHelper.seed_specific_product_features("container_dashboard")
      expect(MiqProductFeature.feature_details("container_dashboard")).to be
    end

    it "eats hidden features" do
      EvmSpecHelper.seed_specific_product_features("widget_refresh")
      expect(MiqProductFeature.feature_details("widget_refresh")).not_to be
    end
  end

  describe "#feature_hidden" do
    it "detects visible features" do
      EvmSpecHelper.seed_specific_product_features("container_dashboard")
      expect(MiqProductFeature.feature_hidden("container_dashboard")).not_to be
    end

    it "detects hidden features" do
      EvmSpecHelper.seed_specific_product_features("widget_refresh")
      expect(MiqProductFeature.feature_hidden("widget_refresh")).to be
    end
  end
end
