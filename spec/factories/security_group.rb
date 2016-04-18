FactoryGirl.define do
  factory :security_group do
    sequence(:name) { |n| "security_group_#{seq_padded_for_sorting(n)}" }
  end

  factory :security_group_amazon, :parent => :security_group,
                                  :class  => "ManageIQ::Providers::Amazon::NetworkManager::SecurityGroup"
  factory :security_group_openstack, :parent => :security_group,
                                     :class  => "ManageIQ::Providers::Openstack::NetworkManager::SecurityGroup"
  factory :security_group_azure, :parent => :security_group,
                                 :class  => "ManageIQ::Providers::Azure::NetworkManager::SecurityGroup"
  factory :security_group_google, :parent => :security_group,
                                  :class  => "ManageIQ::Providers::Google::CloudManager::SecurityGroup"
end
