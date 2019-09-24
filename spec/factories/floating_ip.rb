FactoryBot.define do
  factory :floating_ip do
    sequence(:address) { |n| ip_from_seq(n) }
  end

  factory :floating_ip_azure, :parent => :floating_ip,
                              :class  => "ManageIQ::Providers::Azure::NetworkManager::FloatingIp"
  factory :floating_ip_openstack, :parent => :floating_ip,
                                  :class  => "ManageIQ::Providers::Openstack::NetworkManager::FloatingIp"
  factory :floating_ip_google, :parent => :floating_ip,
                               :class  => "ManageIQ::Providers::Google::NetworkManager::FloatingIp"
end
