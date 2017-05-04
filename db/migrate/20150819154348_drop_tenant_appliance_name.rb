class DropTenantApplianceName < ActiveRecord::Migration[4.2]
  def up
    remove_column :tenants, :appliance_name
  end

  def down
    add_column :tenants, :appliance_name, :string
  end
end
