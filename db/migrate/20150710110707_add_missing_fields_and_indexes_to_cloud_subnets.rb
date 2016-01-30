class AddMissingFieldsAndIndexesToCloudSubnets < ActiveRecord::Migration
  def change
    add_column :cloud_subnets, :cloud_tenant_id,                :bigint
    add_column :cloud_subnets, :dns_nameservers,                :string
    add_column :cloud_subnets, :ipv6_router_advertisement_mode, :string
    add_column :cloud_subnets, :ipv6_address_mode,              :string
    add_column :cloud_subnets, :extra_attributes,               :text

    add_index :cloud_subnets, :ems_id
    add_index :cloud_subnets, :cloud_tenant_id
    add_index :cloud_subnets, :cloud_network_id
  end
end
