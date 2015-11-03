require 'spec_helper'

describe MiqAeMethodService::MiqAeServiceClassification do
  before do
    @cat1 = FactoryGirl.create(:classification_department_with_tags)
    @cat2 = FactoryGirl.create(:classification_cost_center_with_tags)
    @cat_array = Classification.categories.collect(&:name)
    @tags_array = @cat2.entries.collect(&:name)
  end

  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:categories) { MiqAeMethodService::MiqAeServiceClassification.categories }

  it "get a list of categories" do
    expect(categories.collect(&:name)).to match_array(@cat_array)
  end

  it "check the tags" do
    cc = categories.detect { |c| c.name == 'cc' }
    tags = cc.entries
    expect(tags.collect(&:name)).to match_array(@tags_array)
  end
end
