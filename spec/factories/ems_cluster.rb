FactoryBot.define do
  factory :ems_cluster do
    sequence(:name) { |n| "cluster_#{seq_padded_for_sorting(n)}" }
  end

  factory :cluster_target, :parent => :ems_cluster do
    after(:create) do |x|
      x.perf_capture_enabled = toggle_on_name_seq(x)
    end
  end

  trait :vmware_ems do
    after(:create) do |cluster|
      zone = FactoryBot.create(:zone)
      ems = FactoryBot.create(:ems_vmware, :zone => zone)
      cluster.ext_management_system = ems
    end
  end

  trait :redhat_ems do
    after(:create) do |cluster|
      zone = FactoryBot.create(:zone)
      ems = FactoryBot.create(:ems_redhat, :zone => zone)
      cluster.ext_management_system = ems
    end
  end

  factory :ems_cluster_openstack, :class => "ManageIQ::Providers::Openstack::InfraManager::EmsCluster", :parent => :ems_cluster

  trait :openstack_ems do
    after(:create) do |cluster|
      zone = FactoryBot.create(:zone)
      ems = FactoryBot.create(:ems_openstack, :zone => zone)
      cluster.ext_management_system = ems
    end
  end
end
