FactoryGirl.define do
  factory :ems_folder do
    sequence(:name) { |n| "Test Folder #{seq_padded_for_sorting(n)}" }
  end

  factory :datacenter, :parent => :ems_folder, :class => "Datacenter"

  factory :storage_cluster, :parent => :ems_folder, :class => "StorageCluster"

  factory :inventory_group,
          :class  => "ManageIQ::Providers::ConfigurationManager::InventoryGroup",
          :parent => :ems_folder

  factory :inventory_root_group,
          :class  => "ManageIQ::Providers::ConfigurationManager::InventoryRootGroup",
          :parent => :ems_folder
end
