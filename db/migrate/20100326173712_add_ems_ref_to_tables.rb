class AddEmsRefToTables < ActiveRecord::Migration
  def self.up
    add_column :vms,            :ems_ref, :string
    add_column :hosts,          :ems_ref, :string
    add_column :storages,       :ems_ref, :string
    add_column :ems_clusters,   :ems_ref, :string
    add_column :ems_folders,    :ems_ref, :string
    add_column :resource_pools, :ems_ref, :string
  end

  def self.down
    remove_column :vms,            :ems_ref
    remove_column :hosts,          :ems_ref
    remove_column :storages,       :ems_ref
    remove_column :ems_clusters,   :ems_ref
    remove_column :ems_folders,    :ems_ref
    remove_column :resource_pools, :ems_ref
  end
end
