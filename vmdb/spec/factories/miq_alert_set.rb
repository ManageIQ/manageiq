FactoryGirl.define do
  factory :miq_alert_set do
    sequence(:name)         { |n| "alert_profile_#{n}" }
    sequence(:description)  { |n| "alert_profile_#{n}" }
  end
end
