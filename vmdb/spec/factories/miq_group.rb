FactoryGirl.define do
  factory :miq_group do
    sequence(:description) { |n| "Test Group #{n}" }
  end
end
