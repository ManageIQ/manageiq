class CreateNetworkPortsAndRouters < ActiveRecord::Migration
  def change
    create_table :network_ports do |t|
      t.string     :type
      t.string     :name
      t.string     :ems_ref
      t.belongs_to :ems,               :type => :bigint
      t.belongs_to :cloud_network,     :type => :bigint
      t.belongs_to :cloud_subnet,      :type => :bigint
      t.string     :mac_address
      t.string     :status
      t.boolean    :admin_state_up
      t.string     :device_owner
      t.string     :device_ref
      t.integer    :device_id,         :type => :bigint
      t.string     :device_type
      t.belongs_to :cloud_tenant,      :type => :bigint
      t.string     :binding_host_id
      t.string     :binding_virtual_interface_type
      t.text       :extra_attributes
    end

    add_index :network_ports, :ems_id
    add_index :network_ports, :cloud_network_id
    add_index :network_ports, :cloud_subnet_id
    add_index :network_ports, [:device_id, :device_type]
    add_index :network_ports, :cloud_tenant_id

    create_table :network_ports_security_groups, :id => false do |t|
      t.belongs_to :network_port,      :type => :bigint
      t.belongs_to :security_group,    :type => :bigint
    end

    add_index :network_ports_security_groups, [:network_port_id, :security_group_id], :unique => true, :name => "index_network_ports_security_groups"

    create_table :network_routers do |t|
      t.string     :type
      t.string     :name
      t.string     :ems_ref
      t.belongs_to :ems,               :type => :bigint
      t.belongs_to :cloud_network,     :type => :bigint
      t.string     :admin_state_up
      t.belongs_to :cloud_tenant,      :type => :bigint
      t.string     :status
      t.text       :extra_attributes
    end

    add_index :network_routers, :ems_id
    add_index :network_routers, :cloud_tenant_id
    add_index :network_routers, :cloud_network_id
  end
end
