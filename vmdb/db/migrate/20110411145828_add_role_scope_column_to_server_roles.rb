class AddRoleScopeColumnToServerRoles < ActiveRecord::Migration
  def self.up
    add_column    :server_roles, :role_scope, :string
  end

  def self.down
    remove_column :server_roles, :role_scope
  end
end
