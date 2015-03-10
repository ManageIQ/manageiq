FactoryGirl.define do
  factory :ext_management_system do
    sequence(:name)      { |n| "ems_#{seq_padded_for_sorting(n)}" }
    sequence(:hostname)  { |n| "ems_#{seq_padded_for_sorting(n)}" }
    sequence(:ipaddress) { |n| ip_from_seq(n) }
    guid                 { MiqUUID.new_guid }
  end

  # Intermediate classes

  factory :ems_infra, :class => "EmsInfra", :parent => :ext_management_system do
  end

  factory :ems_cloud, :class => "EmsCloud", :parent => :ext_management_system do
  end

  factory :ems_container, :class => "EmsContainer", :parent => :ext_management_system do
  end

  factory :configuration_manager, :class => "ConfigurationManager", :parent => :ext_management_system do
  end

  factory :provisioning_manager, :class => "ProvisioningManager", :parent => :ext_management_system do
  end

  # Leaf classes for ems_infra

  factory :ems_vmware, :class => "EmsVmware", :parent => :ems_infra do
  end

  factory :ems_vmware_with_authentication, :parent => :ems_vmware do
    after(:create) do |x|
      x.authentications << FactoryGirl.create(:authentication)
    end
  end

  factory :ems_microsoft, :class => "EmsMicrosoft", :parent => :ems_infra do
  end

  factory :ems_microsoft_with_authentication, :parent => :ems_microsoft do
    after(:create) do |x|
      x.authentications << FactoryGirl.create(:authentication)
    end
  end

  factory :ems_redhat, :class => "EmsRedhat", :parent => :ems_infra do
  end

  factory :ems_redhat_with_authentication, :parent => :ems_redhat do
    after(:create) do |x|
      x.authentications << FactoryGirl.create(:authentication)
    end
  end

  factory :ems_openstack_infra, :class => "EmsOpenstackInfra", :parent => :ems_infra do
  end

  factory :ems_openstack_infra_with_authentication, :parent => :ems_openstack_infra do
    after :create do |x|
      x.authentications << FactoryGirl.create(:authentication, :userid => "admin", :password => "123456789")
      x.authentications << FactoryGirl.create(:authentication, :userid => "qpid_user", :password => "qpid_password", :authtype => "amqp")
    end
  end

  # Leaf classes for ems_cloud

  factory :ems_amazon, :class => "EmsAmazon", :parent => :ems_cloud do
    provider_region "us-east-1"
  end

  factory :ems_amazon_with_authentication, :parent => :ems_amazon do
    after(:create) do |x|
      x.authentications << FactoryGirl.create(:authentication, :userid => "0123456789ABCDEFGHIJ", :password => "ABCDEFGHIJKLMNO1234567890abcdefghijklmno")
    end
  end

  factory :ems_amazon_with_authentication_on_other_account, :parent => :ems_amazon do
    after(:create) do |x|
      x.authentications << FactoryGirl.create(:authentication)
    end
  end

  factory :ems_openstack, :class => "EmsOpenstack", :parent => :ems_cloud do
  end

  factory :ems_openstack_with_authentication, :parent => :ems_openstack do
    after :create do |x|
      x.authentications << FactoryGirl.create(:authentication, :userid => "admin", :password => "123456789")
      x.authentications << FactoryGirl.create(:authentication, :userid => "qpid_user", :password => "qpid_password", :authtype => "amqp")
    end
  end

  # Leaf classes for ems_container

  factory :ems_kubernetes, :class => "EmsKubernetes", :parent => :ems_container do
  end

  # Leaf classes for configuration_manager

  factory :configuration_manager_foreman, :class => "ConfigurationManagerForeman", :parent => :configuration_manager do
  end

  factory :configuration_manager_foreman_with_authentication, :parent => :configuration_manager_foreman do
    after :create do |x|
      x.authentications << FactoryGirl.create(:authentication)
    end
  end

  # Leaf classes for provisioning_manager

  factory :provisioning_manager_foreman, :class => "ProvisioningManagerForeman", :parent => :provisioning_manager do
  end

  factory :provisioning_manager_foreman_with_authentication, :parent => :provisioning_manager_foreman do
    after :create do |x|
      x.authentications << FactoryGirl.create(:authentication)
    end
  end
end
