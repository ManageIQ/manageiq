FactoryGirl.define do
  factory :flavor do
  end

  factory :flavor_amazon, :parent => :flavor, :class => "ManageIQ::Providers::Amazon::CloudManager::Flavor" do
  end

  factory :flavor_openstack, :parent => :flavor, :class => "ManageIQ::Providers::Openstack::CloudManager::Flavor" do
  end

  factory :flavor_google, :parent => :flavor, :class => "ManageIQ::Providers::Google::CloudManager::Flavor" do
  end
end
