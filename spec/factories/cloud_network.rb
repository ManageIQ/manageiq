FactoryGirl.define do
  factory :cloud_network do
    sequence(:name)    { |n| "cloud_network_#{seq_padded_for_sorting(n)}" }
    sequence(:ems_ref) { |n| "ems_ref_#{seq_padded_for_sorting(n)}" }
  end

  factory :cloud_network_openstack, :class  => "ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork",
                                    :parent => :cloud_network
  factory :cloud_network_amazon, :class  => "ManageIQ::Providers::Amazon::NetworkManager::CloudNetwork",
                                 :parent => :cloud_network
  factory :cloud_network_azure, :class  => "ManageIQ::Providers::Azure::NetworkManager::CloudNetwork",
                                :parent => :cloud_network
end
