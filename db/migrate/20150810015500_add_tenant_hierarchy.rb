class AddTenantHierarchy < ActiveRecord::Migration[4.2]
  def change
    add_column :tenants, :ancestry, :string
    add_index :tenants, :ancestry
  end
end
