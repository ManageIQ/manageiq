FactoryGirl.define do
  factory :cloud_tenant do
    sequence(:name)    { |n| "cloud_tenant_#{n}" }
    sequence(:ems_ref) { |n| "ems_ref_#{n}" }
  end
end
