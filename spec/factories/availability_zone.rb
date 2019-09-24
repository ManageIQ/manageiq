FactoryBot.define do
  factory :availability_zone do
    sequence(:name)     { |n| "availability_zone_#{seq_padded_for_sorting(n)}" }
  end

  factory :availability_zone_amazon, :parent => :availability_zone, :class => "ManageIQ::Providers::Amazon::CloudManager::AvailabilityZone"

  factory :availability_zone_azure,
          :parent => :availability_zone,
          :class  => "ManageIQ::Providers::Azure::CloudManager::AvailabilityZone"

  factory :availability_zone_openstack, :parent => :availability_zone, :class => "ManageIQ::Providers::Openstack::CloudManager::AvailabilityZone"

  factory :availability_zone_openstack_null, :parent => :availability_zone_openstack, :class => "ManageIQ::Providers::Openstack::CloudManager::AvailabilityZoneNull"

  factory :availability_zone_google, :parent => :availability_zone, :class => "ManageIQ::Providers::Google::CloudManager::AvailabilityZone"

  factory :availability_zone_vmware,
          :parent => :availability_zone,
          :class  => "ManageIQ::Providers::Vmware::CloudManager::AvailabilityZone"

  factory :availability_zone_target, :parent => :availability_zone do
    after(:create) do |x|
      x.perf_capture_enabled = true
    end
  end
end
