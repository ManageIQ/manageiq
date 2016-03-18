FactoryGirl.define do
  factory :floating_ip do
    sequence(:address) { |n| ip_from_seq(n) }
  end

  factory :floating_ip_amazon, :parent => :floating_ip, :class => "ManageIQ::Providers::Amazon::CloudManager::FloatingIp" do
  end

  factory :floating_ip_openstack, :parent => :floating_ip, :class => "ManageIQ::Providers::Openstack::NetworkManager::FloatingIp" do
  end
end
