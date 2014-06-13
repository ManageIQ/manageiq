FactoryGirl.define do
  factory :availability_zone do
    sequence(:name)     { |n| "availability_zone_#{n}" }
  end

  factory :availability_zone_amazon, :parent => :availability_zone, :class => "AvailabilityZoneAmazon" do
  end

  factory :availability_zone_openstack, :parent => :availability_zone, :class => "AvailabilityZoneOpenstack" do
  end

  factory :availability_zone_openstack_null, :parent => :availability_zone_openstack, :class => "AvailabilityZoneOpenstackNull" do
  end

  factory :availability_zone_target, :parent => :availability_zone do
    after(:create) do |x|
      x.perf_capture_enabled = true
    end
  end
end
