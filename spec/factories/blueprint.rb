FactoryGirl.define do
  factory :blueprint do
    sequence(:name) { |n| "Blueprint #{n}" }
  end
end
