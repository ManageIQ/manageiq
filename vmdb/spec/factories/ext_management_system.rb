FactoryGirl.define do
  factory :ext_management_system do
    sequence(:name)      { |n| "ems_#{seq_padded_for_sorting(n)}" }
    sequence(:hostname)  { |n| "ems_#{seq_padded_for_sorting(n)}" }
    sequence(:ipaddress) { |n| ip_from_seq(n) }
    guid                 { MiqUUID.new_guid }
  end

  factory :ems_vmware, :class => "EmsVmware", :parent => :ext_management_system do
  end

  factory :ems_vmware_with_authentication, :parent => :ems_vmware do
    after(:create) do |x|
      x.authentications << FactoryGirl.create(:authentication)
    end
  end

  factory :ems_microsoft, :class => "EmsMicrosoft", :parent => :ext_management_system do
  end

  factory :ems_microsoft_with_authentication, :parent => :ems_microsoft do
    after(:create) do |x|
      x.authentications << FactoryGirl.create(:authentication)
    end
  end

  factory :ems_redhat, :class => "EmsRedhat", :parent => :ext_management_system do
  end

  factory :ems_redhat_with_authentication, :parent => :ems_redhat do
    after(:create) do |x|
      x.authentications << FactoryGirl.create(:authentication)
    end
  end

  factory :ems_kvm, :class => "EmsKvm", :parent => :ext_management_system do
  end

  factory :ems_amazon, :class => "EmsAmazon", :parent => :ext_management_system do
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

  factory :ems_openstack, :class => "EmsOpenstack", :parent => :ext_management_system do
  end

  factory :ems_openstack_with_authentication, :parent => :ems_openstack do
    after :create do |x|
      x.authentications << FactoryGirl.create(:authentication, :userid => "admin", :password => "123456789")
      x.authentications << FactoryGirl.create(:authentication, :userid => "qpid_user", :password => "qpid_password", :authtype => "amqp")
    end
  end

  factory :ems_openstack_infra, :class => "EmsOpenstackInfra", :parent => :ext_management_system do
  end
end
