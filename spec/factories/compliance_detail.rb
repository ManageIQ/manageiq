FactoryBot.define do
  factory :compliance_detail do
    sequence(:id) { |n| 10_000_000 + n }
    created_on { DateTime .current }
    updated_on { DateTime.current }
    miq_policy_desc { 'Policy description' }
    miq_policy_result { true }
    condition_desc { 'Condition description' }
    condition_result { true }
  end
end
