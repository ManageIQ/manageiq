FactoryBot.define do
  factory :provider do
    sequence(:name) { |n| "provider_#{seq_padded_for_sorting(n)}" }
    zone            { FactoryBot.create(:zone) }
  end

  factory :provider_foreman, :class => "ManageIQ::Providers::Foreman::Provider", :parent => :provider do
    sequence(:url) { |n| "example_#{seq_padded_for_sorting(n)}.com" }

    after(:build) do |provider|
      provider.authentications << FactoryBot.build(:authentication,
                                                    :userid   => "admin",
                                                    :password => "smartvm")
    end
  end

  factory :provider_openstack, :class => "ManageIQ::Providers::Openstack::Provider", :parent => :provider
  factory(:provider_ansible_tower, :class => "ManageIQ::Providers::AnsibleTower::Provider", :parent => :provider) do
    sequence(:url) { |n| "example_#{seq_padded_for_sorting(n)}.com" }
    trait(:with_authentication) do
      after(:create) do |x|
        x.authentications << FactoryBot.create(:authentication)
      end
    end
  end
  factory :provider_embedded_ansible, :class => "ManageIQ::Providers::EmbeddedAnsible::Provider", :parent => :provider
end
