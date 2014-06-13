class AddOpenstackFieldsToCloudNetworks < ActiveRecord::Migration
  def change
    add_column :cloud_networks, :status, :string
    add_column :cloud_networks, :enabled, :boolean
    add_column :cloud_networks, :external_facing, :boolean
  end
end
