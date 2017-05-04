class ChangeCloudTenantDescriptionToText < ActiveRecord::Migration[4.2]
  def up
    change_column :cloud_tenants, :description, :text
  end

  def down
    change_column :cloud_tenants, :description, :string
  end
end
