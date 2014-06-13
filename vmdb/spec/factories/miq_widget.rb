FactoryGirl.define do
  factory :miq_widget do
    sequence(:title)        { |n| "widget_#{n}" }
    sequence(:description)  { |n| "widget_#{n}" }
    content_type            "report"
  end
end
