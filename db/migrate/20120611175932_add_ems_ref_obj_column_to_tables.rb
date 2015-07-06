class AddEmsRefObjColumnToTables < ActiveRecord::Migration
  class EmsCluster < ActiveRecord::Base
    self.inheritance_column = nil
  end

  class EmsFolder < ActiveRecord::Base
    self.inheritance_column = nil
  end

  class Host < ActiveRecord::Base
    self.inheritance_column = nil
  end

  class ResourcePool < ActiveRecord::Base
    self.inheritance_column = nil
  end

  class Snapshot < ActiveRecord::Base
    self.inheritance_column = nil
  end

  class Storage < ActiveRecord::Base
    self.inheritance_column = nil
  end

  class Vm < ActiveRecord::Base
    self.inheritance_column = nil
  end

  def up
    rename_column :ems_clusters,   :ems_ref, :ems_ref_obj
    rename_column :ems_folders,    :ems_ref, :ems_ref_obj
    rename_column :hosts,          :ems_ref, :ems_ref_obj
    rename_column :resource_pools, :ems_ref, :ems_ref_obj
    rename_column :snapshots,      :ems_ref, :ems_ref_obj
    rename_column :storages,       :ems_ref, :ems_ref_obj
    rename_column :vms,            :ems_ref, :ems_ref_obj

    add_column :ems_clusters,   :ems_ref, :string
    add_column :ems_folders,    :ems_ref, :string
    add_column :hosts,          :ems_ref, :string
    add_column :resource_pools, :ems_ref, :string
    add_column :snapshots,      :ems_ref, :string
    add_column :storages,       :ems_ref, :string
    add_column :vms,            :ems_ref, :string

    [EmsCluster, EmsFolder, Host, ResourcePool, Snapshot, Storage, Vm].each do |model|
      say_with_time("Migrating ems_ref column for #{model.table_name}") do
        model.all.each do |r|
          next if r.ems_ref_obj.nil?
          ems_ref = r.ems_ref_obj
          ems_ref = YAML.load(ems_ref) if ems_ref.starts_with?("---")
          r.update_attribute(:ems_ref, ems_ref.to_s) unless r.ems_ref_obj.nil?
        end
      end
    end
  end

  def down
    remove_column :ems_clusters,   :ems_ref
    remove_column :ems_folders,    :ems_ref
    remove_column :hosts,          :ems_ref
    remove_column :resource_pools, :ems_ref
    remove_column :snapshots,      :ems_ref
    remove_column :storages,       :ems_ref
    remove_column :vms,            :ems_ref

    rename_column :ems_clusters,   :ems_ref_obj, :ems_ref
    rename_column :ems_folders,    :ems_ref_obj, :ems_ref
    rename_column :hosts,          :ems_ref_obj, :ems_ref
    rename_column :resource_pools, :ems_ref_obj, :ems_ref
    rename_column :snapshots,      :ems_ref_obj, :ems_ref
    rename_column :storages,       :ems_ref_obj, :ems_ref
    rename_column :vms,            :ems_ref_obj, :ems_ref
  end
end
