describe MiqAeMethodService::MiqAeServiceClassification do
  before do
    FactoryGirl.create(:classification_department_with_tags)
    @cc_cat = FactoryGirl.create(:classification_cost_center_with_tags)
  end

  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:categories) { MiqAeMethodService::MiqAeServiceClassification.categories }

  it "get a list of categories" do
    cat_array = Classification.categories.collect(&:name)
    expect(categories.collect(&:name)).to match_array(cat_array)
  end

  it "check the tags" do
    tags_array = @cc_cat.entries.collect(&:name)
    cc = categories.detect { |c| c.name == 'cc' }
    tags = cc.entries
    expect(tags.collect(&:name)).to match_array(tags_array)
  end
end
