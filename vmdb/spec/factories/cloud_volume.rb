FactoryGirl.define do
  factory :cloud_volume do
  end

  factory :cloud_volume_amazon, :parent => :cloud_volume do
  end

  factory :cloud_volume_openstack, :parent => :cloud_volume do
  end
end
