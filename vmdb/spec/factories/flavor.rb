FactoryGirl.define do
  factory :flavor do
  end

  factory :flavor_amazon, :parent => :flavor, :class => "ManageIQ::Providers::Amazon::CloudManager::Flavor" do
  end

  factory :flavor_openstack, :parent => :flavor, :class => :FlavorOpenstack do
  end
end
