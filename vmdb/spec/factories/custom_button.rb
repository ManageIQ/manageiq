FactoryGirl.define do
  factory :custom_button do
    sequence(:name)        { |n| "custom_button_#{n}" }
    sequence(:description) { |n| "custom_button_#{n}" }
  end
end
