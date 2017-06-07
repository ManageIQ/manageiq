FactoryGirl.define do
  factory :showback_bucket do
    sequence(:name)           { |n| "factory_bucket_#{seq_padded_for_sorting(n)}" }
    sequence(:description)    { |n| "bucket_description_#{seq_padded_for_sorting(n)}" }
    start_time                4.hours.ago
    end_time                  1.hour.ago
    state                     "OPEN"
    association :resource, :factory => :miq_enterprise, :strategy => :build_stubbed
  end

  factory :showback_bucket_processing, :parent => :showback_bucket do
    state "PROCESSING"
  end

  factory :showback_bucket_close, :parent => :showback_bucket do
    state "CLOSE"
  end
end
