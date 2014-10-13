FactoryGirl.define do
  factory :classification do
    sequence(:name)        { |n| "category_#{n}" }
    sequence(:description) { |n| "category #{n}" }
    syntax    "string"
    parent_id 0
  end

  factory :classification_cost_center, :parent => :classification do
    name        "cc"
    description "Cost Center"
  end

  factory :classification_tag, :class => :Classification do
    sequence(:name)        { |n| "tag_#{n}" }
    sequence(:description) { |n| "tag #{n}" }
    syntax "string"
  end

  factory :classification_tag_cost_center, :parent => :classification_tag do
    name        "001"
    description "Cost Center 001"
    parent      { FactoryGirl.create(:classification_cost_center) }
  end
end
