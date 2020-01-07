FactoryBot.define do
  factory :ems_cluster do
    sequence(:name) { |n| "cluster_#{seq_padded_for_sorting(n)}" }
  end

  factory :ems_cluster_openstack, :class => "ManageIQ::Providers::Openstack::InfraManager::Cluster", :parent => :ems_cluster
  factory :ems_cluster_ovirt, :class => "ManageIQ::Providers::Redhat::InfraManager::Cluster", :parent => :ems_cluster
end
