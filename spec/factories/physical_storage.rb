FactoryBot.define do
  factory :physical_storage,
          :class => "ManageIQ::Providers::Autosde::StorageManager::PhysicalStorage" do
    name { "test_physical_storage" }
  end

  factory :physical_storage_autosde,
          :parent => :physical_storage do
    sequence(:ems_ref) { |n| "some-uuid-#{seq_padded_for_sorting(n)}" }
  end
end
