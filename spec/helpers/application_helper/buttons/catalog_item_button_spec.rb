require 'spec_helper'

describe ApplicationHelper::Button::CatalogItemButton do
  let (:session) { Hash.new }
  before do
    @view_context = setup_view_context_with_sandbox({})
    allow(@view_context).to receive(:current_user).and_return(FactoryGirl.create(:user))
    @button = described_class.new(@view_context, {}, {}, {:child_id => "ab_button_new"})
  end

  context "#role_allows_feature?" do
    it "will be skipped" do
      expect(@button.role_allows_feature?).to be false
    end

    it "won't be skipped" do
      EvmSpecHelper.seed_specific_product_features("catalogitem_new")
      feature = MiqProductFeature.find_all_by_identifier(["everything"])
      allow(@view_context).to receive(:current_user).and_return(FactoryGirl.create(:user, :features => feature))
      expect(@button.role_allows_feature?).to be true
    end
  end
end
