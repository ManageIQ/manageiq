FactoryBot.define do
  factory :cloud_volume_type do
    sequence(:name)         { |n| "cloud_volume_type_#{seq_padded_for_sorting(n)}" }
    sequence(:description)  { |n| "cloud_volume_type_description_#{seq_padded_for_sorting(n)}" }
    sequence(:ems_ref)      { |n| "ems_ref_#{seq_padded_for_sorting(n)}" }
  end

  factory :cloud_volume_type_openstack,
          :class => "ManageIQ::Providers::Openstack::StorageManager::CinderManager::CloudVolumeType",
          :parent => :cloud_volume_type
end
