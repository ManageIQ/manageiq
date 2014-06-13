class CreateVdiClasses < ActiveRecord::Migration
  def self.up

    create_table :vdi_farms do |t|
      t.string      :name
      t.string      :vendor
      t.string      :edition
      t.string      :uid_ems
      t.string      :license_server_name
      t.string      :enable_session_reliability
      t.timestamps
    end

    create_table :vdi_controllers do |t|
      t.bigint      :vdi_farm_id
      t.string      :name
      t.string      :version
      t.string      :zone_preference
      t.timestamps
    end

    create_table :vdi_desktop_pools do |t|
      t.bigint      :vdi_farm_id
      t.bigint      :ems_id
      t.string      :name
      t.string      :description
      t.string      :vendor
      t.boolean     :enabled
      t.string      :uid_ems
      t.string      :assignment_behavior
      t.string      :hosting_vendor
      t.string      :hosting_server
      t.string      :hosting_ipaddress
      t.string      :default_encryption_level
      t.string      :default_color_depth
      t.timestamps
    end

    create_table :vdi_desktops do |t|
      t.bigint      :vdi_desktop_pool_id
      t.bigint      :vdi_user_id
      t.bigint      :vm_id
      t.string      :name
      t.string      :agent_version
      t.string      :connection_state
      t.string      :power_state
      t.string      :assigned_username
      t.boolean     :maintenance_mode
      t.string      :vm_uid_ems
      t.timestamps
    end

    create_table :vdi_users do |t|
      t.string      :uid_ems
      t.string      :name
      t.timestamps
    end

    create_table :vdi_sessions do |t|
      t.bigint      :vdi_desktop_id
      t.bigint      :vdi_controller_id
      t.bigint      :vdi_user_id
      t.string      :user_name
      t.string      :state
      t.datetime    :start_time
      t.string      :encryption_level
      t.string      :protocol
      t.string      :endpoint_id
      t.string      :endpoint_address
      t.string      :endpoint_name
      t.string      :horizontal_resolution
      t.string      :vertical_resolution
      t.timestamps
    end

  end

  def self.down
    drop_table :vdi_farms
    drop_table :vdi_controllers
    drop_table :vdi_desktop_pools
    drop_table :vdi_desktops
    drop_table :vdi_sessions
    drop_table :vdi_users
  end
end
