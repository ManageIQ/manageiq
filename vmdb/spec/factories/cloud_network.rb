FactoryGirl.define do
  factory :cloud_network do
    sequence(:name)    { |n| "cloud_network_#{n}" }
    sequence(:ems_ref) { |n| "ems_ref_#{n}" }
  end
end
