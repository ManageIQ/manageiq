FactoryGirl.define do
  factory :service do
    sequence(:name) { |n| "service_#{n}" }
  end
end
