class AddVdiCisToEmsEvents < ActiveRecord::Migration
  def self.up
    add_column     :ems_events, :vdi_endpoint_device_id,    :bigint
    add_column     :ems_events, :vdi_endpoint_device_name,  :string
    add_column     :ems_events, :vdi_controller_id,         :bigint
    add_column     :ems_events, :vdi_controller_name,       :string
    add_column     :ems_events, :vdi_user_id,               :bigint
    add_column     :ems_events, :vdi_user_name,             :string
    add_column     :ems_events, :vdi_desktop_id,            :bigint
    add_column     :ems_events, :vdi_desktop_name,          :string
    add_column     :ems_events, :vdi_desktop_pool_id,       :bigint
    add_column     :ems_events, :vdi_desktop_pool_name,     :string
  end

  def self.down
    remove_column  :ems_events, :vdi_endpoint_device_id
    remove_column  :ems_events, :vdi_endpoint_device_name
    remove_column  :ems_events, :vdi_controller_id
    remove_column  :ems_events, :vdi_controller_name
    remove_column  :ems_events, :vdi_user_id
    remove_column  :ems_events, :vdi_user_name
    remove_column  :ems_events, :vdi_desktop_id
    remove_column  :ems_events, :vdi_desktop_name
    remove_column  :ems_events, :vdi_desktop_pool_id
    remove_column  :ems_events, :vdi_desktop_pool_name
  end
end
