FactoryBot.define do
  factory :security_group do
    sequence(:name) { |n| "security_group_#{seq_padded_for_sorting(n)}" }
  end

  factory :security_group_with_firewall_rules, :parent => :security_group do
    firewall_rules { build_list :firewall_rule, 3 }
  end

  factory :security_group_amazon, :parent => :security_group,
                                  :class  => "ManageIQ::Providers::Amazon::NetworkManager::SecurityGroup"
  factory :security_group_openstack, :parent => :security_group,
                                     :class  => "ManageIQ::Providers::Openstack::NetworkManager::SecurityGroup"
  factory :security_group_azure, :parent => :security_group,
                                 :class  => "ManageIQ::Providers::Azure::NetworkManager::SecurityGroup"
  factory :security_group_google, :parent => :security_group,
                                  :class  => "ManageIQ::Providers::Google::NetworkManager::SecurityGroup"
  factory :security_group_nsxt,
          :class  => "ManageIQ::Providers::Nsxt::NetworkManager::SecurityGroup",
          :parent => :security_policy
  factory :security_group_with_firewall_rules_openstack,
          :parent => :security_group_with_firewall_rules,
          :class  => "ManageIQ::Providers::Openstack::NetworkManager::SecurityGroup"
end
