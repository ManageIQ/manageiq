FactoryGirl.define do
  factory :security_group do
  end

  factory :security_group_amazon, :parent => :security_group, :class => "ManageIQ::Providers::Amazon::CloudManager::SecurityGroup" do
  end

  factory :security_group_openstack, :parent => :security_group, :class => :SecurityGroupOpenstack do
  end
end
