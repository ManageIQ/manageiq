class AddSupportedCapabilitiesToStorage < ActiveRecord::Migration
  def self.up
    add_column :storages, :directory_hierarchy_supported, :boolean
    add_column :storages, :thin_provisioning_supported, :boolean
    add_column :storages, :raw_disk_mappings_supported, :boolean
  end

  def self.down
    remove_column :storages, :directory_hierarchy_supported
    remove_column :storages, :thin_provisioning_supported
    remove_column :storages, :raw_disk_mappings_supported
  end
end
