FactoryGirl.define do
  factory :miq_ae_namespace do
    sequence(:name) { |n| "miq_ae_namespace_#{n}" }
  end
end
