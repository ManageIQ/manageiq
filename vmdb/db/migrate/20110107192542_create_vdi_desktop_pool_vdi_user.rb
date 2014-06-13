class CreateVdiDesktopPoolVdiUser < ActiveRecord::Migration
  def self.up
    create_table :vdi_desktop_pools_vdi_users, :id => false do |t|
      t.bigint   :vdi_desktop_pool_id
      t.bigint   :vdi_user_id
    end

    create_table :vdi_endpoint_devices do |t|
      t.string      :name
      t.string      :ipaddress
      t.string      :uid_ems
      t.timestamps
    end

    add_column :miq_proxies,  :vdi_farm_id,            :bigint
    add_column :vdi_sessions, :vdi_endpoint_device_id, :bigint
    add_column :vdi_sessions, :uid_ems,                :string

    remove_column :vdi_sessions, :endpoint_id
    remove_column :vdi_sessions, :endpoint_name
    remove_column :vdi_sessions, :endpoint_address
  end

  def self.down
    drop_table    :vdi_desktop_pools_vdi_users
    drop_table    :vdi_endpoint_devices

    remove_column :miq_proxies,  :vdi_farm_id
    remove_column :vdi_sessions, :vdi_endpoint_device_id
    remove_column :vdi_sessions, :uid_ems

    add_column    :vdi_sessions, :endpoint_id,            :string
    add_column    :vdi_sessions, :endpoint_name,          :string
    add_column    :vdi_sessions, :endpoint_address,       :string
  end
end
