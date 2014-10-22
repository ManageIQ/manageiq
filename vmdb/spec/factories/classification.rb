FactoryGirl.define do
  factory :classification do
    sequence(:name)        { |n| "category_#{n}" }
    sequence(:description) { |n| "category #{n}" }
    parent_id 0
  end

  factory :classification_tag, :class => :Classification do
    sequence(:name)        { |n| "tag_#{n}" }
    sequence(:description) { |n| "tag #{n}" }
  end

  #
  # Classification categories
  #

  factory :classification_cost_center, :parent => :classification do
    name        "cc"
    description "Cost Center"
  end

  #
  # Classification categories with child tags
  #

  factory :classification_cost_center_with_tags, :parent => :classification_cost_center do
    children {
      [
        FactoryGirl.create(:classification_tag, :name => "001", :description => "Cost Center 001"),
      ]
    }
  end
end
