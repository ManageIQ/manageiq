FactoryGirl.define do
  factory :miq_enterprise do
    sequence(:name) { |n| "miq_enterprise_#{n}" }
  end
end
