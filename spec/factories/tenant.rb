FactoryGirl.define do
  factory :tenant do
    sequence(:subdomain) { |n| "tenant#{n}" }
  end
end
