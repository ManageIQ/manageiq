class AddAdminDisabledToHost < ActiveRecord::Migration
  def self.up
    add_column :hosts, :admin_disabled, :boolean
  end

  def self.down
    remove_column :hosts, :admin_disabled
  end
end
