FactoryGirl.define do
  factory :miq_ae_namespace do
    sequence(:name) { |n| "miq_ae_namespace_#{n}" }
  end

  factory :miq_ae_domain_enabled, :parent => :miq_ae_namespace do
    enabled true
  end

  factory :miq_ae_domain_disabled, :parent => :miq_ae_namespace do
  end
end
