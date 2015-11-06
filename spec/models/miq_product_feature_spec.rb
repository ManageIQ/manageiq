require "spec_helper"
require 'tmpdir'
require 'pathname'

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

  context ".seed_features" do
    let(:feature_path) { Pathname.new(Dir.tmpdir).join(rand(1000).to_s) }

    before do
      FileUtils.mkdir_p(feature_path)
    end

    after do
      FileUtils.rm_rf(feature_path)
    end

    it "additional yaml feature" do
      base = {
        :feature_type => "node",
        :identifier   => "everything",
        :children     => [
          {
            :feature_type => "node",
            :identifier   => "one",
            :children     => []
          }
        ]
      }

      additional = {
        :feature_type => "node",
        :identifier   => "two",
        :children     => []
      }

      additional_file = feature_path.join("additional.yml")
      File.write("#{feature_path}.yml", YAML.dump(base))
      File.write(additional_file, YAML.dump(additional))

      status_seed = MiqProductFeature.seed_features(feature_path)
      MiqProductFeature.count.should eq(3)
      expect(status_seed[:created]).to match_array %w(everything one two)
    end
  end
end
