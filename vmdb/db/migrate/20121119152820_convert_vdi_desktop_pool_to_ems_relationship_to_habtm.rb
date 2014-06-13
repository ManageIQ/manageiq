class ConvertVdiDesktopPoolToEmsRelationshipToHabtm < ActiveRecord::Migration
  class VdiDesktopPool < ActiveRecord::Base; end
  class ExtManagementSystemsVdiDesktopPools < ActiveRecord::Base
    self.primary_key = nil
  end

  def up
    create_table :ext_management_systems_vdi_desktop_pools, :id => false do |t|
      t.bigint   :ems_id
      t.bigint   :vdi_desktop_pool_id
    end

    say_with_time("Migrating VDI Desktop Pools") do
      VdiDesktopPool.where("ems_id IS NOT NULL").each do |vdi_desktop_pool|
        ExtManagementSystemsVdiDesktopPools.create!(:vdi_desktop_pool_id => vdi_desktop_pool.id, :ems_id => vdi_desktop_pool.ems_id)
      end
    end

    remove_column :vdi_desktop_pools, :ems_id
  end

  def down
    add_column :vdi_desktop_pools, :ems_id, :bigint

    say_with_time("Migrating VDI Desktop Pools") do
      ExtManagementSystemsVdiDesktopPools.group(:vdi_desktop_pool_id).select([:vdi_desktop_pool_id, "MIN(ems_id) AS ems_id"]).each do |join|
        VdiDesktopPool.where(:id => join.vdi_desktop_pool_id).update_all(:ems_id => join.ems_id)
      end
    end

    drop_table :ext_management_systems_vdi_desktop_pools
  end

end
