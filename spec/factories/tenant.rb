FactoryGirl.define do
  factory :tenant do
    sequence(:name) { |n| "Tenant #{n}" }
    sequence(:subdomain) { |n| "tenant#{n}" }
    parent { Tenant.seed }
  end

  factory :tenant_with_cloud_tenant, :parent => :tenant do
    source { FactoryGirl.create(:cloud_tenant) }
  end
end
