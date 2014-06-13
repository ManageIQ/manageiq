FactoryGirl.define do
  factory :classification do
    sequence(:name)        { |n| "category_#{n}" }
    sequence(:description) { |n| "category #{n}" }
    syntax    "string"
    parent_id 0
  end

  factory :classification_tag, :class => :Classification do
    sequence(:name)        { |n| "tag_#{n}" }
    sequence(:description) { |n| "tag #{n}" }
    syntax "string"
  end
end
