FactoryGirl.define do
  factory :cloud_subnet do
    sequence(:name)    { |n| "cloud_subnet_#{n}" }
    sequence(:ems_ref) { |n| "ems_ref_#{n}" }
  end
end
