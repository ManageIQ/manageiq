FactoryBot.define do
  factory :ems_folder do
    sequence(:name) { |n| "Test Folder #{seq_padded_for_sorting(n)}" }
  end

  factory :datacenter, :parent => :ems_folder, :class => "Datacenter"

  factory :storage_cluster, :parent => :ems_folder, :class => "StorageCluster"

  factory :inventory_group,
          :class  => "ManageIQ::Providers::AutomationManager::InventoryGroup",
          :parent => :ems_folder

  factory :inventory_root_group,
          :class  => "ManageIQ::Providers::AutomationManager::InventoryRootGroup",
          :parent => :ems_folder

  #
  # VMware specific folders
  #

  factory :vmware_folder,
          :parent => :ems_folder, :class => "ManageIQ::Providers::Vmware::InfraManager::Folder" do
    sequence(:ems_ref) { |n| "group-d#{n}" }
    ems_ref_type       { "Folder" }
  end

  factory :vmware_folder_vm, :parent => :vmware_folder do
    sequence(:ems_ref) { |n| "group-v#{n}" }
  end

  factory :vmware_folder_host, :parent => :vmware_folder do
    sequence(:ems_ref) { |n| "group-h#{n}" }
  end

  factory :vmware_folder_datastore, :parent => :vmware_folder do
    sequence(:ems_ref) { |n| "group-s#{n}" }
  end

  factory :vmware_folder_network, :parent => :vmware_folder do
    sequence(:ems_ref) { |n| "group-n#{n}" }
  end

  factory :vmware_folder_root, :parent => :vmware_folder do
    name   { "Datacenters" }
    hidden { true }
  end

  factory :vmware_folder_vm_root, :parent => :vmware_folder_vm do
    name   { "vm" }
    hidden { true }
  end

  factory :vmware_folder_host_root, :parent => :vmware_folder_host do
    name   { "host" }
    hidden { true }
  end

  factory :vmware_folder_datastore_root, :parent => :vmware_folder_datastore do
    name   { "datastore" }
    hidden { true }
  end

  factory :vmware_folder_network_root, :parent => :vmware_folder_network do
    name   { "network" }
    hidden { true }
  end

  factory :vmware_datacenter,
          :parent => :datacenter, :class => "ManageIQ::Providers::Vmware::InfraManager::Datacenter" do
    sequence(:name)    { |n| "Test Datacenter #{seq_padded_for_sorting(n)}" }
    sequence(:ems_ref) { |n| "datacenter-#{n}" }
    ems_ref_type       { "Datacenter" }
  end
end

def build_vmware_folder_structure!(ems)
  ems.add_child(
    FactoryBot.create(:vmware_folder_root, :ems_id => ems.id).tap do |root|
      root.add_child(
        FactoryBot.create(:vmware_folder, :name => "yellow1", :ems_id => ems.id).tap do |f|
          f.add_child(
            FactoryBot.create(:vmware_datacenter, :ems_id => ems.id).tap do |dc|
              dc.add_children(
                FactoryBot.create(:vmware_folder_vm_root, :ems_id => ems.id) do |vm|
                  vm.add_children(
                    FactoryBot.create(:vmware_folder_vm, :name => "blue1", :ems_id => ems.id),
                    FactoryBot.create(:vmware_folder_vm, :name => "blue2", :ems_id => ems.id)
                  )
                end,
                FactoryBot.create(:vmware_folder_host_root, :ems_id => ems.id),
                FactoryBot.create(:vmware_folder_datastore_root, :ems_id => ems.id),
                FactoryBot.create(:vmware_folder_network_root, :ems_id => ems.id)
              )
            end
          )
        end
      )
    end
  )
end
