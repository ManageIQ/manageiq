require "spec_helper"
require Rails.root.join("db/migrate/20140415212812_add_hidden_column_to_product_features.rb")

describe AddHiddenColumnToProductFeatures do
  migration_context :up do
    let(:miq_product_feature_stub)    { migration_stub(:MiqProductFeature) }

    it "adds hidden column to Product Features" do
      feature = miq_product_feature_stub.create!(:identifier => "some_id")
      migrate
      feature.reload.hidden.should be_nil
    end
  end
end
