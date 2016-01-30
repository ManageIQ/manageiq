FactoryGirl.define do
  factory :provider do
    sequence(:name) { |n| "provider_#{seq_padded_for_sorting(n)}" }
    guid            { MiqUUID.new_guid }
  end

  factory :provider_foreman, :class => "ManageIQ::Providers::Foreman::Provider", :parent => :provider do
    url "example.com"

    after(:build) do |provider|
      provider.authentications << FactoryGirl.build(:authentication,
                                                    :userid   => "admin",
                                                    :password => "smartvm")
    end
  end

  factory :provider_openstack, :class => "ManageIQ::Providers::Openstack::Provider", :parent => :provider
  factory(:provider_ansible_tower, :class => "ManageIQ::Providers::AnsibleTower::Provider", :parent => :provider) do
    url "example.com"
  end
end
