FactoryGirl.define do
  factory :showback_bucket do
    sequence(:name)           { |n| "factory_bucket_#{seq_padded_for_sorting(n)}" }
    sequence(:description)    { |n| "bucket_description_#{seq_padded_for_sorting(n)}" }
    association :resource, factory: :miq_enterprise, strategy: :build_stubbed
  end
end
