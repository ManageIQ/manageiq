class CreateCloudNetworksAndSubnets < ActiveRecord::Migration
  def change
    create_table :cloud_networks do |t|
      t.string     :name
      t.string     :ems_ref
      t.belongs_to :ems,               :type => :bigint
      t.string     :cidr
    end

    create_table :cloud_subnets do |t|
      t.string     :name
      t.string     :ems_ref
      t.belongs_to :ems,               :type => :bigint
      t.belongs_to :availability_zone, :type => :bigint
      t.belongs_to :cloud_network,     :type => :bigint
      t.string     :cidr
      t.string     :status
    end

    add_column :floating_ips,    :cloud_network_only, :boolean
    add_column :security_groups, :cloud_network_id,   :bigint
    add_column :vms,             :cloud_network_id,   :bigint
    add_column :vms,             :cloud_subnet_id,    :bigint
  end
end
