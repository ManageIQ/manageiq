FactoryBot.define do
  factory :cloud_volume do
    sequence(:volume_type) { |n| "volume_type_#{seq_padded_for_sorting(n)}" }
  end

  factory :cloud_volume_openstack, :class => "ManageIQ::Providers::Openstack::CloudManager::CloudVolume", :parent => :cloud_volume do
    status { "available" }
  end
end
