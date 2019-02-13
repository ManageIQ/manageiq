FactoryBot.define do
  factory :classification do
    sequence(:name)        { |n| "category_#{seq_padded_for_sorting(n)}" }
    sequence(:description) { |n| "category #{seq_padded_for_sorting(n)}" }
    parent_id { 0 }
  end

  factory :classification_tag, :class => :Classification do
    sequence(:name)        { |n| "tag_#{seq_padded_for_sorting(n)}" }
    sequence(:description) { |n| "tag #{seq_padded_for_sorting(n)}" }
  end

  #
  # Classification categories
  #

  factory :classification_cost_center, :parent => :classification do
    name        { "cc" }
    description { "Cost Center" }
  end

  factory :classification_department, :parent => :classification do
    name        { "department" }
    description { "Department" }
  end

  #
  # Classification categories with child tags
  #

  factory :classification_cost_center_with_tags, :parent => :classification_cost_center do
    after(:create) do |c|
      FactoryBot.create(:classification_tag, :name => "001", :description => "Cost Center 001", :parent => c)
    end
  end

  factory :classification_department_with_tags, :parent => :classification_department do
    after(:create) do |c|
      FactoryBot.create(:classification_tag, :parent => c, :name => "accounting", :description => "Accounting")
      FactoryBot.create(:classification_tag, :parent => c, :name => "finance",    :description => "Financial Services")
      FactoryBot.create(:classification_tag, :parent => c, :name => "hr",         :description => "Human Resources")
    end
  end
end
