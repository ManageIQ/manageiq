FactoryBot.define do
  factory :tenant do
    sequence(:name) { |n| "Tenant #{n}" }
    sequence(:subdomain) { |n| "tenant#{n}" }
    parent { Tenant.seed }
  end

  trait :in_other_region do
    other_region

    after(:create) do |instance, evaluator|
      instance.default_miq_group = FactoryGirl.create(:miq_group, :in_other_region, :other_region => evaluator.other_region, :default_tenant => instance)
    end
  end

  factory :tenant_with_cloud_tenant, :parent => :tenant do
    source { FactoryBot.create(:cloud_tenant) }
  end

  factory :tenant_project, :parent => :tenant do
    divisible { false }
  end
end
