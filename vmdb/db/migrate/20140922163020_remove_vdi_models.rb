class RemoveVdiModels < ActiveRecord::Migration
  def up
    change_table "ems_events" do |t|
      t.remove "vdi_endpoint_device_id"
      t.remove "vdi_endpoint_device_name"
      t.remove "vdi_controller_id"
      t.remove "vdi_controller_name"
      t.remove "vdi_user_id"
      t.remove "vdi_user_name"
      t.remove "vdi_desktop_id"
      t.remove "vdi_desktop_name"
      t.remove "vdi_desktop_pool_id"
      t.remove "vdi_desktop_pool_name"
    end

    drop_table "ext_management_systems_vdi_desktop_pools"

    remove_index  "miq_proxies", "vdi_farm_id"
    remove_column "ldap_users",  "vdi_user_id"
    remove_column "miq_proxies", "vdi_farm_id"

    remove_index "vdi_controllers", "vdi_farm_id"
    drop_table   "vdi_controllers"

    remove_index "vdi_desktop_pools", "vdi_farm_id"
    drop_table   "vdi_desktop_pools"

    remove_index "vdi_desktop_pools_vdi_users", "vdi_desktop_pool_id"
    remove_index "vdi_desktop_pools_vdi_users", "vdi_user_id"
    drop_table   "vdi_desktop_pools_vdi_users"

    remove_index "vdi_desktops", "vdi_desktop_pool_id"
    if index_exists?('vdi_desktops', :name => 'index_vdi_desktops_on_vm_id')
      remove_index "vdi_desktops", :name => "index_vdi_desktops_on_vm_id"
    else
      remove_index "vdi_desktops", :name => "index_vdi_desktops_on_vm_or_template_id"
    end
    drop_table   "vdi_desktops"

    drop_table "vdi_desktops_vdi_users"
    drop_table "vdi_endpoint_devices"
    drop_table "vdi_farms"

    remove_index "vdi_sessions", "vdi_controller_id"
    remove_index "vdi_sessions", "vdi_desktop_id"
    remove_index "vdi_sessions", "vdi_endpoint_device_id"
    remove_index "vdi_sessions", "vdi_user_id"
    drop_table   "vdi_sessions"
    drop_table   "vdi_users"

    remove_column "vms", "vdi"
  end

  def down
    change_table "ems_events" do |t|
      t.integer "vdi_endpoint_device_id",    :limit => 8
      t.string  "vdi_endpoint_device_name"
      t.integer "vdi_controller_id",         :limit => 8
      t.string  "vdi_controller_name"
      t.integer "vdi_user_id",               :limit => 8
      t.string  "vdi_user_name"
      t.integer "vdi_desktop_id",            :limit => 8
      t.string  "vdi_desktop_name"
      t.integer "vdi_desktop_pool_id",       :limit => 8
      t.string  "vdi_desktop_pool_name"
    end

    create_table "ext_management_systems_vdi_desktop_pools", :id => false do |t|
      t.bigint "ems_id"
      t.bigint "vdi_desktop_pool_id"
    end

    add_column "ldap_users",  "vdi_user_id", "bigint"
    add_column "miq_proxies", "vdi_farm_id", "bigint"
    add_index  "miq_proxies", ["vdi_farm_id"], :name => "index_miq_proxies_on_vdi_farm_id"

    create_table "vdi_controllers" do |t|
      t.bigint   "vdi_farm_id"
      t.string   "name"
      t.string   "version"
      t.string   "zone_preference"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "vdi_controllers", ["vdi_farm_id"], :name => "index_vdi_controllers_on_vdi_farm_id"

    create_table "vdi_desktop_pools" do |t|
      t.bigint   "vdi_farm_id"
      t.string   "name"
      t.string   "description"
      t.string   "vendor"
      t.boolean  "enabled"
      t.string   "uid_ems"
      t.string   "assignment_behavior"
      t.string   "hosting_vendor"
      t.string   "hosting_server"
      t.string   "hosting_ipaddress"
      t.string   "default_encryption_level"
      t.string   "default_color_depth"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "vdi_desktop_pools", ["vdi_farm_id"], :name => "index_vdi_desktop_pools_on_vdi_farm_id"

    create_table "vdi_desktop_pools_vdi_users", :id => false do |t|
      t.bigint "vdi_desktop_pool_id"
      t.bigint "vdi_user_id"
    end

    add_index "vdi_desktop_pools_vdi_users", ["vdi_desktop_pool_id"], :name => "index_vdi_desktop_pools_vdi_users_on_vdi_desktop_pool_id"
    add_index "vdi_desktop_pools_vdi_users", ["vdi_user_id"], :name => "index_vdi_desktop_pools_vdi_users_on_vdi_user_id"

    create_table "vdi_desktops" do |t|
      t.bigint   "vdi_desktop_pool_id"
      t.bigint   "vm_or_template_id"
      t.string   "name"
      t.string   "agent_version"
      t.string   "connection_state"
      t.string   "power_state"
      t.string   "assigned_username"
      t.boolean  "maintenance_mode"
      t.string   "vm_uid_ems"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "vdi_desktops", ["vdi_desktop_pool_id"], :name => "index_vdi_desktops_on_vdi_desktop_pool_id"
    add_index "vdi_desktops", ["vm_or_template_id"], :name => "index_vdi_desktops_on_vm_id"

    create_table "vdi_desktops_vdi_users", :id => false do |t|
      t.bigint "vdi_desktop_id"
      t.bigint "vdi_user_id"
    end

    create_table "vdi_endpoint_devices" do |t|
      t.string   "name"
      t.string   "ipaddress"
      t.string   "uid_ems"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "vdi_farms" do |t|
      t.string   "name"
      t.string   "vendor"
      t.string   "edition"
      t.string   "uid_ems"
      t.string   "license_server_name"
      t.string   "enable_session_reliability"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.bigint   "zone_id"
      t.string   "type"
    end

    create_table "vdi_sessions" do |t|
      t.bigint   "vdi_desktop_id"
      t.bigint   "vdi_controller_id"
      t.bigint   "vdi_user_id"
      t.string   "user_name"
      t.string   "state"
      t.datetime "start_time"
      t.string   "encryption_level"
      t.string   "protocol"
      t.string   "horizontal_resolution"
      t.string   "vertical_resolution"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.bigint   "vdi_endpoint_device_id"
      t.string   "uid_ems"
    end

    add_index "vdi_sessions", ["vdi_controller_id"], :name => "index_vdi_sessions_on_vdi_controller_id"
    add_index "vdi_sessions", ["vdi_desktop_id"], :name => "index_vdi_sessions_on_vdi_desktop_id"
    add_index "vdi_sessions", ["vdi_endpoint_device_id"], :name => "index_vdi_sessions_on_vdi_endpoint_device_id"
    add_index "vdi_sessions", ["vdi_user_id"], :name => "index_vdi_sessions_on_vdi_user_id"

    create_table "vdi_users" do |t|
      t.string   "uid_ems"
      t.string   "name"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_column "vms", "vdi", :boolean, :default => false, :null => false
  end
end
