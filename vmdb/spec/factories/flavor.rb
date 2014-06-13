FactoryGirl.define do
  factory :flavor do
  end

  factory :flavor_amazon, :parent => :flavor, :class => :FlavorAmazon do
  end

  factory :flavor_openstack, :parent => :flavor, :class => :FlavorOpenstack do
  end
end
