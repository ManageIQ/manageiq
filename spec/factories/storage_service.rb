FactoryBot.define do
  factory :storage_service do
    association :ext_management_system, :factory => :ems_storage
    capabilities { {} }
  end
end
