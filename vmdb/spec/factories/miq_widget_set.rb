FactoryGirl.define do
  factory :miq_widget_set do
    sequence(:name)         { |n| "widget_set_#{n}" }
    sequence(:description)  { |n| "widget_set_#{n}" }
  end
end
