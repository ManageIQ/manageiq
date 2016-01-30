class ChangeCloudTenantDescriptionToText < ActiveRecord::Migration
  def up
    change_column :cloud_tenants, :description, :text
  end

  def down
    change_column :cloud_tenants, :description, :string
  end
end
