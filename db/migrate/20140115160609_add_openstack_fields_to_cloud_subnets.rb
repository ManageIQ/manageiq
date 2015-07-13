class AddOpenstackFieldsToCloudSubnets < ActiveRecord::Migration
  def change
    add_column :cloud_subnets, :dhcp_enabled, :boolean
    add_column :cloud_subnets, :gateway, :string
    add_column :cloud_subnets, :network_protocol, :string
  end
end
