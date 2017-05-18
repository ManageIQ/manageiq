class AddTenantDescription < ActiveRecord::Migration[4.2]
  def change
    add_column :tenants, :description, :text
  end
end
