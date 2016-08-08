FactoryGirl.define do
  factory :arbitration_profile do
    name                   'profile'
    description            'an arbitration profile'
    default_profile        false
    ext_management_system  { FactoryGirl.create(:ems_cloud) }

    trait :default do
      default_profile true
    end
  end
end
