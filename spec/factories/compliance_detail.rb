FactoryGirl.define do
  factory :compliance_detail do
    sequence(:id)          { |n| 10000000 + n }
    created_on DateTime .now
    updated_on DateTime.now
    miq_policy_desc 'Policy description'
    miq_policy_result true
    condition_desc 'Condition description'
    condition_result true

  end
end