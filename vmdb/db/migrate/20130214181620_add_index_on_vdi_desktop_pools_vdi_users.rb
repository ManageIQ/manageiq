class AddIndexOnVdiDesktopPoolsVdiUsers < ActiveRecord::Migration
  extend MigrationHelper

  def self.up
    add_index :vdi_desktop_pools_vdi_users, :vdi_desktop_pool_id
    add_index :vdi_desktop_pools_vdi_users, :vdi_user_id
  end

  def self.down
    remove_index :vdi_desktop_pools_vdi_users, :vdi_desktop_pool_id
    remove_index :vdi_desktop_pools_vdi_users, :vdi_user_id
  end
end
