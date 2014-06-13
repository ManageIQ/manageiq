FactoryGirl.define do
  factory :miq_action do
    sequence(:name)  { |num| "action_#{num}" }
    description      "Test Action"
    action_type      "Test"
  end
end
