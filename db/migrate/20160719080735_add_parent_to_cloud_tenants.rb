class AddParentToCloudTenants < ActiveRecord::Migration[5.0]
  def change
    add_column :cloud_tenants, :parent_id, :bigint
  end
end
