FactoryGirl.define do
  factory :cloud_tenant do
    sequence(:name)    { |n| "cloud_tenant_#{seq_padded_for_sorting(n)}" }
    sequence(:ems_ref) { |n| "ems_ref_#{seq_padded_for_sorting(n)}" }
  end
end
