FactoryGirl.define do
  factory :classification do
    sequence(:name)        { |n| "category_#{seq_padded_for_sorting(n)}" }
    sequence(:description) { |n| "category #{seq_padded_for_sorting(n)}" }
    parent_id 0
  end

  factory :classification_tag, :class => :Classification do
    sequence(:name)        { |n| "tag_#{seq_padded_for_sorting(n)}" }
    sequence(:description) { |n| "tag #{seq_padded_for_sorting(n)}" }
  end

  #
  # Classification categories
  #

  factory :classification_cost_center, :parent => :classification do
    name        "cc"
    description "Cost Center"
  end

  factory :classification_department, :parent => :classification do
    name        "deparment"
    description "Department"
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

  factory :classification_department_with_tags, :parent => :classification_department do
    children {
      [
        FactoryGirl.create(:classification_tag, :name => "accounting", :description => "Accounting"),
        FactoryGirl.create(:classification_tag, :name => "finance",    :description => "Financial Services"),
        FactoryGirl.create(:classification_tag, :name => "hr",         :description => "Human Resources"),
      ]
    }
  end
end
