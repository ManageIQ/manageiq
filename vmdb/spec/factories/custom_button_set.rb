FactoryGirl.define do
  factory :custom_button_set do
    sequence(:name)        { |n| "custom_button_set_#{n}" }
    sequence(:description) { |n| "custom_button_set_#{n}" }
  end
end
