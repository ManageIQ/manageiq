FactoryGirl.define do
  factory :floating_ip do
    sequence(:address) { |n| ip_from_seq(n) }
  end

  factory :floating_ip_amazon, :parent => :floating_ip, :class => :FloatingIpAmazon do
  end

  factory :floating_ip_openstack, :parent => :floating_ip, :class => :FloatingIpOpenstack do
  end
end
