class AddTenantDescription < ActiveRecord::Migration
  def change
    add_column :tenants, :description, :text
  end
end
