FactoryBot.define do
  factory :cloud_volume_backup do
    sequence(:name)    { |n| "cloud_volume_backup_#{seq_padded_for_sorting(n)}" }
    sequence(:ems_ref) { |n| "ems_ref_#{seq_padded_for_sorting(n)}" }
  end

  factory :cloud_volume_backup_openstack, :parent => :cloud_volume_backup, :class => "ManageIQ::Providers::Openstack::CloudManager::CloudVolumeBackup"
end
