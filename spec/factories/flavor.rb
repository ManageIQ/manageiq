FactoryGirl.define do
  factory :flavor do
    sequence(:name) { |n| "flavor_#{seq_padded_for_sorting(n)}" }
  end

  factory :flavor_amazon,    :parent => :flavor, :class => "ManageIQ::Providers::Amazon::CloudManager::Flavor"
  factory :flavor_google,    :parent => :flavor, :class => "ManageIQ::Providers::Google::CloudManager::Flavor"
  factory :flavor_openstack, :parent => :flavor, :class => "ManageIQ::Providers::Openstack::CloudManager::Flavor"
  factory :flavor_azure,     :parent => :flavor, :class => "ManageIQ::Providers::Azure::CloudManager::Flavor"
end
