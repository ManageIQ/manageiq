class AddTenantHierarchy < ActiveRecord::Migration
  def change
    add_column :tenants, :ancestry, :string
    add_index :tenants, :ancestry
  end
end
