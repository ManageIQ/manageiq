FactoryGirl.define do
  factory :cloud_volume do
  end

  factory :cloud_volume_openstack, :class => "ManageIQ::Providers::Openstack::CloudManager::CloudVolume", :parent => :cloud_volume do
    status "available"
  end
end
