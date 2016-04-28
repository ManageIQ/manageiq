require 'tmpdir'
require 'pathname'

describe MiqProductFeature do
  let(:expected_feature_count) { 1017 }

  # - container_dashboard
  # - miq_report_widget_editor
  #   - miq_report_widget_admin
  #     - widget_edit
  #     - widget_copy
  #     - widget_refresh (H)
  let(:hierarchical_features) do
    EvmSpecHelper.seed_specific_product_features(
      %w(miq_report_widget_editor miq_report_widget_admin widget_refresh widget_edit widget_copy container_dashboard)
    )
  end

  context ".seed" do
    it "creates feature identifiers once on first seed, changes nothing on second seed" do
      status_seed1 = MiqProductFeature.seed
      expect(MiqProductFeature.count).to eq(expected_feature_count)
      expect(status_seed1[:created]).to match_array status_seed1[:created].uniq
      expect(status_seed1[:updated]).to match_array []
      expect(status_seed1[:unchanged]).to match_array []

      status_seed2 = MiqProductFeature.seed
      expect(MiqProductFeature.count).to eq(expected_feature_count)
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
      expect(changed.reload.name).to eq("One")
      expect(unchanged.reload.updated_at).to be_same_time_as unchanged_orig_updated_at
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
      expect(MiqProductFeature.count).to eq(3)
      expect(status_seed[:created]).to match_array %w(everything one two)

      additional_file.unlink
      Dir.rmdir(feature_path)
    end
  end

  describe '#feature_children' do
    it "returns only visible features" do
      hierarchical_features
      expect(MiqProductFeature).not_to receive(:sort_children)
      expect(MiqProductFeature.feature_children("miq_report_widget_admin", false)).to match_array(
        %w(widget_copy widget_edit))
    end

    it "returns direct children only" do
      hierarchical_features
      expect(MiqProductFeature.feature_children("miq_report_widget_editor")).to eq(
        %w(miq_report_widget_admin))
    end

    it "sorts features" do
      hierarchical_features
      expect(MiqProductFeature).to receive(:sort_children).and_call_original
      expect(MiqProductFeature.feature_children("miq_report_widget_admin")).to eq(%w(widget_copy widget_edit))
    end
  end

  describe '#feature_all_children' do
    it "returns all visible children" do
      hierarchical_features
      expect(MiqProductFeature).not_to receive(:sort_children)
      expect(MiqProductFeature.feature_all_children("miq_report_widget_editor", false)).to match_array(
        %w(widget_copy widget_edit miq_report_widget_admin))
    end

    it "returns all visible children sorted" do
      hierarchical_features
      expect(MiqProductFeature).to receive(:sort_children).and_call_original
      expect(MiqProductFeature.feature_all_children("miq_report_widget_editor")).to eq(
        %w(widget_copy widget_edit miq_report_widget_admin))
    end
  end

  describe "#feature_details" do
    it "returns data for visible features" do
      EvmSpecHelper.seed_specific_product_features("container_dashboard")
      expect(MiqProductFeature.feature_details("container_dashboard")).to be_truthy
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
      expect(MiqProductFeature.feature_hidden("widget_refresh")).to be_truthy
    end
  end
end
