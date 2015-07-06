FactoryGirl.define do
  factory :miq_alert_set do
    sequence(:name)         { |n| "alert_profile_#{seq_padded_for_sorting(n)}" }
    sequence(:description)  { |n| "alert_profile_#{seq_padded_for_sorting(n)}" }
  end
end
