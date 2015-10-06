class AddMissingFieldsAndIndexesToCloudNetworks < ActiveRecord::Migration
  def change
    add_column :cloud_networks, :provider_physical_network, :string
    add_column :cloud_networks, :provider_network_type,     :string
    add_column :cloud_networks, :provider_segmentation_id,  :string
    add_column :cloud_networks, :vlan_transparent,          :boolean
    add_column :cloud_networks, :extra_attributes,          :text

    add_index :cloud_networks, :ems_id
    add_index :cloud_networks, :cloud_tenant_id
  end
end
