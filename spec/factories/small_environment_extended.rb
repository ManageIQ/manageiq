# %w{small_environment}.each do |m|
#   require File.join(File.dirname(__FILE__), m) unless Factory.factories.has_key?(m.to_sym)
# end

FactoryGirl.define do
  factory :small_environment_with_storages, :parent => :small_environment do
    after(:create) do |x|
      storages = [FactoryGirl.create(:storage, :name => "storage 1", :store_type => "VMFS"),
                  FactoryGirl.create(:storage, :name => "storage 2", :store_type => "VMFS")]

      ems  = x.ext_management_systems.first
      host = ems.hosts.first
      [ems, host].each {|ci| storages.each{|s| ci.storages << s}}

      ems.vms.each_with_index do |vm, idx|
        vm.update_attribute(:storage_id, storages[idx].id)
        vm.storages << storages[idx]
      end
    end
  end

  factory :small_environment_host_with_default_resource_pool, :parent => :small_environment_with_storages do
    after(:create) do |x|
      ems  = x.ext_management_systems.first
      host = ems.hosts.first
      default_res_pool = FactoryGirl.create(:resource_pool, :name => "Default for Host #{host.name}", :is_default => true)

      ems.resource_pools << default_res_pool
      default_res_pool.set_parent(host)
      ems.vms.each {|vm| default_res_pool.add_vm(vm)}
    end
  end

  factory :small_environment_host_with_resource_pools, :parent => :small_environment_host_with_default_resource_pool do
    after(:create) do |x|
      res_pool_1 = FactoryGirl.create(:resource_pool, :name => "ResPool 1", :is_default => false)
      ems = x.ext_management_systems.first
      ems.hosts.first.default_resource_pool.add_resource_pool(res_pool_1)
      res_pool_1.add_vm(ems.vms.first)
    end
  end

  factory :small_environment_cluster_with_default_resource_pool, :parent => :small_environment_with_storages do
    after(:create) do |x|
      ems = x.ext_management_systems.first

      cluster = FactoryGirl.create(:ems_cluster, :name => "cluster 1", :ext_management_system => ems, :hosts => [ems.hosts.first], :vms => ems.vms)
      default_res_pool = FactoryGirl.create(:resource_pool, :name => "Default for Cluster #{cluster.name}", :is_default => true, :ext_management_system => ems)
      cluster.add_resource_pool(default_res_pool)

      ems.vms.each do |vm|
        default_res_pool.add_vm(vm)
      end
    end
  end

  factory :small_environment_cluster_with_resource_pools, :parent => :small_environment_cluster_with_default_resource_pool do
    after(:create) do |x|
      res_pool_1 = FactoryGirl.create(:resource_pool, :name => "ResPool 1", :is_default => false)
      ems = x.ext_management_systems.first
      ems.ems_clusters.first.default_resource_pool.add_resource_pool(res_pool_1)
      res_pool_1.add_vm(ems.vms.first)
    end
  end
end
