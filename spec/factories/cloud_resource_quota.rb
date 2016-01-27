FactoryGirl.define do
  factory :cloud_resource_quota do
    sequence(:name)    { |n| "cloud_resource_quota_#{seq_padded_for_sorting(n)}" }
    sequence(:ems_ref) { |n| "ems_ref_#{seq_padded_for_sorting(n)}" }
  end
end
