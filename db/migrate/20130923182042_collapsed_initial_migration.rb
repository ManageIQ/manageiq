require Rails.root.join('lib/migration_helper')

class CollapsedInitialMigration < ActiveRecord::Migration
  include MigrationHelper

  def up
    create_table "accounts" do |t|
      t.string   "name"
      t.integer  "acctid"
      t.string   "homedir"
      t.boolean  "local"
      t.string   "domain"
      t.string   "accttype"
      t.bigint   "vm_or_template_id"
      t.string   "display_name"
      t.string   "comment"
      t.string   "expires"
      t.boolean  "enabled"
      t.datetime "last_logon"
      t.bigint   "host_id"
    end

    add_index "accounts", ["accttype"], :name => "index_accounts_on_accttype"
    add_index "accounts", ["host_id"], :name => "index_accounts_on_host_id"
    add_index "accounts", ["vm_or_template_id"], :name => "index_accounts_on_vm_id"

    create_table "advanced_settings" do |t|
      t.string   "name"
      t.string   "display_name"
      t.string   "description"
      t.text     "value"
      t.string   "default_value"
      t.string   "min"
      t.string   "max"
      t.boolean  "read_only"
      t.string   "resource_type"
      t.bigint   "resource_id"
      t.datetime "created_on"
      t.datetime "updated_on"
    end

    add_index "advanced_settings", ["resource_id", "resource_type"], :name => "index_advanced_settings_on_resource_id_and_resource_type"

    create_table "assigned_server_roles" do |t|
      t.bigint  "miq_server_id"
      t.bigint  "server_role_id"
      t.boolean "active"
      t.integer "priority"
    end

    add_index "assigned_server_roles", ["miq_server_id"], :name => "index_assigned_server_roles_on_miq_server_id"
    add_index "assigned_server_roles", ["server_role_id"], :name => "index_assigned_server_roles_on_server_role_id"

    create_table "audit_events" do |t|
      t.string   "event"
      t.string   "status"
      t.text     "message"
      t.string   "severity"
      t.bigint   "target_id"
      t.string   "target_class"
      t.string   "userid"
      t.string   "source"
      t.datetime "created_on"
    end

    add_index "audit_events", ["target_id", "target_class"], :name => "index_audit_events_on_target_id_and_target_class"

    create_table "authentications" do |t|
      t.string   "name"
      t.string   "authtype"
      t.string   "userid"
      t.string   "password"
      t.bigint   "resource_id"
      t.string   "resource_type"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.datetime "last_valid_on"
      t.datetime "last_invalid_on"
      t.datetime "credentials_changed_on"
      t.string   "status"
      t.string   "status_details"
      t.string   "type"
      t.text     "auth_key"
      t.string   "fingerprint"
    end

    add_index "authentications", ["resource_id", "resource_type"], :name => "index_authentications_on_resource_id_and_resource_type"

    create_table "availability_zones" do |t|
      t.bigint  "ems_id"
      t.string  "name"
      t.string  "ems_ref"
      t.string  "type"
    end

    add_index "availability_zones", ["ems_id"], :name => "index_availability_zones_on_ems_id"

    create_table "binary_blob_parts" do |t|
      t.string  "md5"
      t.binary  "data"
      t.bigint  "binary_blob_id"
      t.decimal "size",                        :precision => 20, :scale => 0
    end

    add_index "binary_blob_parts", ["binary_blob_id"], :name => "index_binary_blob_parts_on_binary_blob_id"

    create_table "binary_blobs" do |t|
      t.string  "resource_type"
      t.bigint  "resource_id"
      t.string  "md5"
      t.decimal "size",                       :precision => 20, :scale => 0
      t.decimal "part_size",                  :precision => 20, :scale => 0
      t.string  "name"
      t.string  "data_type"
    end

    add_index "binary_blobs", ["resource_id", "resource_type"], :name => "index_binary_blobs_on_resource_id_and_resource_type"

    create_table "bottleneck_events" do |t|
      t.datetime "timestamp"
      t.datetime "created_on"
      t.string   "resource_name"
      t.string   "resource_type"
      t.bigint   "resource_id"
      t.string   "event_type"
      t.integer  "severity"
      t.string   "message"
      t.text     "context_data"
      t.boolean  "future"
    end

    add_index "bottleneck_events", ["resource_id", "resource_type"], :name => "index_bottleneck_events_on_resource_id_and_resource_type"

    create_table "chargeback_rate_details" do |t|
      t.boolean  "enabled",                         :default => true
      t.string   "description"
      t.string   "group"
      t.string   "source"
      t.string   "metric"
      t.string   "rate"
      t.string   "per_time"
      t.string   "per_unit"
      t.string   "friendly_rate"
      t.bigint   "chargeback_rate_id"
      t.datetime "created_on"
      t.datetime "updated_on"
    end

    add_index "chargeback_rate_details", ["chargeback_rate_id"], :name => "index_chargeback_rate_details_on_chargeback_rate_id"

    create_table "chargeback_rates" do |t|
      t.string   "guid",        :limit => 36
      t.string   "description"
      t.string   "rate_type"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.boolean  "default",                   :default => false
    end

    create_table "classifications" do |t|
      t.text    "description"
      t.string  "icon"
      t.boolean "read_only"
      t.string  "syntax"
      t.boolean "single_value"
      t.text    "example_text"
      t.bigint  "tag_id"
      t.bigint  "parent_id",                 :default => 0
      t.boolean "show"
      t.boolean "default"
      t.boolean "perf_by_tag"
    end

    add_index "classifications", ["parent_id"], :name => "index_classifications_on_parent_id"
    add_index "classifications", ["tag_id"], :name => "index_classifications_on_tag_id"

    create_table "cloud_networks" do |t|
      t.string  "name"
      t.string  "ems_ref"
      t.bigint  "ems_id"
      t.string  "cidr"
    end

    create_table "cloud_subnets" do |t|
      t.string  "name"
      t.string  "ems_ref"
      t.bigint  "ems_id"
      t.bigint  "availability_zone_id"
      t.bigint  "cloud_network_id"
      t.string  "cidr"
      t.string  "status"
    end

    create_table "cloud_volume_snapshots" do |t|
      t.string  "type"
      t.string  "ems_ref"
      t.bigint  "ems_id"
      t.bigint  "cloud_volume_id"
      t.string  "name"
      t.string  "description"
    end

    create_table "cloud_volumes" do |t|
      t.string  "type"
      t.string  "ems_ref"
      t.string  "device_name"
      t.bigint  "size"
      t.bigint  "ems_id"
      t.bigint  "availability_zone_id"
      t.bigint  "cloud_volume_snapshot_id"
      t.bigint  "vm_id"
      t.string  "name"
    end

    create_table "compliance_details" do |t|
      t.bigint   "compliance_id"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.bigint   "miq_policy_id"
      t.string   "miq_policy_desc"
      t.boolean  "miq_policy_result"
      t.bigint   "condition_id"
      t.string   "condition_desc"
      t.boolean  "condition_result"
    end

    add_index "compliance_details", ["compliance_id"], :name => "index_compliance_details_on_compliance_id"
    add_index "compliance_details", ["condition_id"], :name => "index_compliance_details_on_condition_id"
    add_index "compliance_details", ["miq_policy_id"], :name => "index_compliance_details_on_miq_policy_id"

    create_table "compliances" do |t|
      t.bigint   "resource_id"
      t.string   "resource_type"
      t.boolean  "compliant"
      t.datetime "timestamp"
      t.datetime "updated_on"
      t.string   "event_type"
    end

    add_index "compliances", ["resource_id", "resource_type"], :name => "index_compliances_on_resource_id_and_resource_type"

    create_table "conditions" do |t|
      t.string   "name"
      t.string   "description"
      t.string   "modifier"
      t.text     "expression"
      t.string   "towhat"
      t.datetime "file_mtime"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "guid",           :limit => 36
      t.string   "filename"
      t.text     "applies_to_exp"
      t.bigint   "miq_policy_id"
      t.string   "notes",          :limit => 512
    end

    add_index "conditions", ["guid"], :name => "index_conditions_on_guid", :unique => true
    add_index "conditions", ["miq_policy_id"], :name => "index_conditions_on_miq_policy_id"

    create_table "conditions_miq_policies", :id => false do |t|
      t.bigint  "miq_policy_id"
      t.bigint  "condition_id"
    end

    create_table "configurations" do |t|
      t.bigint   "miq_server_id"
      t.string   "typ"
      t.text     "settings"
      t.datetime "created_on"
      t.datetime "updated_on"
    end

    add_index "configurations", ["miq_server_id"], :name => "index_configurations_on_miq_server_id"

    create_table "custom_attributes" do |t|
      t.string  "section"
      t.string  "name"
      t.string  "value"
      t.string  "resource_type"
      t.bigint  "resource_id"
      t.string  "source"
    end

    add_index "custom_attributes", ["resource_id", "resource_type"], :name => "index_custom_attributes_on_resource_id_and_resource_type"

    create_table "custom_buttons" do |t|
      t.string   "guid",              :limit => 36
      t.string   "description"
      t.string   "applies_to_class"
      t.text     "applies_to_exp"
      t.text     "options"
      t.string   "userid"
      t.boolean  "wait_for_complete"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "name"
      t.text     "visibility"
      t.bigint   "applies_to_id"
    end

    create_table "customization_specs" do |t|
      t.string   "name"
      t.bigint   "ems_id"
      t.string   "typ"
      t.text     "description"
      t.datetime "last_update_time"
      t.text     "spec"
      t.datetime "created_at",                    :null => false
      t.datetime "updated_at",                    :null => false
    end

    add_index "customization_specs", ["ems_id"], :name => "index_customization_specs_on_ems_id"

    create_table "customization_templates" do |t|
      t.string   "name"
      t.string   "description"
      t.text     "script"
      t.datetime "created_at",                     :null => false
      t.datetime "updated_at",                     :null => false
      t.bigint   "pxe_image_type_id"
      t.string   "type"
      t.boolean  "system"
    end

    create_table "database_backups" do |t|
      t.string   "name"
      t.datetime "created_at",                 :null => false
      t.datetime "updated_at",                 :null => false
      t.bigint   "miq_region_id"
    end

    add_index "database_backups", ["miq_region_id"], :name => "index_database_backups_on_miq_region_id"

    create_table "dialog_fields" do |t|
      t.string   "name"
      t.string   "description"
      t.string   "type"
      t.string   "data_type"
      t.string   "notes"
      t.string   "notes_display"
      t.string   "display"
      t.string   "display_method"
      t.text     "display_method_options"
      t.boolean  "required"
      t.string   "required_method"
      t.text     "required_method_options"
      t.string   "default_value"
      t.text     "values"
      t.string   "values_method"
      t.text     "values_method_options"
      t.text     "options"
      t.datetime "created_at",                           :null => false
      t.datetime "updated_at",                           :null => false
      t.string   "label"
      t.bigint   "dialog_group_id"
      t.integer  "position"
    end

    create_table "dialog_groups" do |t|
      t.string   "description"
      t.string   "display"
      t.datetime "created_at",                          :null => false
      t.datetime "updated_at",                          :null => false
      t.string   "label"
      t.string   "display_method"
      t.text     "display_method_options"
      t.bigint   "dialog_tab_id"
      t.integer  "position"
    end

    create_table "dialog_tabs" do |t|
      t.string   "description"
      t.string   "display"
      t.datetime "created_at",                          :null => false
      t.datetime "updated_at",                          :null => false
      t.string   "label"
      t.string   "display_method"
      t.text     "display_method_options"
      t.bigint   "dialog_id"
      t.integer  "position"
    end

    create_table "dialogs" do |t|
      t.string   "description"
      t.string   "buttons"
      t.datetime "created_at",  :null => false
      t.datetime "updated_at",  :null => false
      t.string   "label"
    end

    create_table "disks" do |t|
      t.string   "device_name"
      t.string   "device_type"
      t.string   "location"
      t.string   "filename"
      t.bigint   "hardware_id"
      t.string   "mode"
      t.string   "controller_type"
      t.bigint   "size"
      t.bigint   "free_space"
      t.bigint   "size_on_disk"
      t.boolean  "present",                      :default => true
      t.boolean  "start_connected",              :default => true
      t.boolean  "auto_detect"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "disk_type"
      t.bigint   "storage_id"
    end

    add_index "disks", ["device_name"], :name => "index_disks_on_device_name"
    add_index "disks", ["device_type"], :name => "index_disks_on_device_type"
    add_index "disks", ["hardware_id"], :name => "index_disks_on_hardware_id"
    add_index "disks", ["storage_id"], :name => "index_disks_on_storage_id"

    create_table "drift_states" do |t|
      t.datetime "timestamp"
      t.bigint   "resource_id"
      t.string   "resource_type"
      t.text     "data"
    end

    add_index "drift_states", ["resource_id", "resource_type", "timestamp"], :name => "index_states_on_resource_id_and_resource_type_and_timestamp"
    add_index "drift_states", ["timestamp"], :name => "index_drift_states_on_timestamp"

    create_table "ems_clusters" do |t|
      t.string   "name"
      t.bigint   "ems_id"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "uid_ems"
      t.boolean  "ha_enabled"
      t.boolean  "ha_admit_control"
      t.integer  "ha_max_failures"
      t.boolean  "drs_enabled"
      t.string   "drs_automation_level"
      t.integer  "drs_migration_threshold"
      t.datetime "last_perf_capture_on"
      t.string   "ems_ref_obj"
      t.bigint   "effective_cpu"
      t.bigint   "effective_memory"
      t.string   "ems_ref"
    end

    add_index "ems_clusters", ["ems_id"], :name => "index_ems_clusters_on_ems_id"
    add_index "ems_clusters", ["uid_ems"], :name => "index_ems_clusters_on_uid"

    create_table "ems_events" do |t|
      t.string   "event_type"
      t.text     "message"
      t.datetime "timestamp"
      t.string   "host_name"
      t.bigint   "host_id"
      t.string   "vm_name"
      t.string   "vm_location"
      t.bigint   "vm_or_template_id"
      t.string   "dest_host_name"
      t.bigint   "dest_host_id"
      t.string   "dest_vm_name"
      t.string   "dest_vm_location"
      t.bigint   "dest_vm_or_template_id"
      t.string   "source"
      t.bigint   "chain_id"
      t.bigint   "ems_id"
      t.boolean  "is_task"
      t.text     "full_data"
      t.datetime "created_on"
      t.string   "username"
      t.bigint   "ems_cluster_id"
      t.string   "ems_cluster_name"
      t.string   "ems_cluster_uid"
      t.bigint   "dest_ems_cluster_id"
      t.string   "dest_ems_cluster_name"
      t.string   "dest_ems_cluster_uid"
      t.bigint   "vdi_endpoint_device_id"
      t.string   "vdi_endpoint_device_name"
      t.bigint   "vdi_controller_id"
      t.string   "vdi_controller_name"
      t.bigint   "vdi_user_id"
      t.string   "vdi_user_name"
      t.bigint   "vdi_desktop_id"
      t.string   "vdi_desktop_name"
      t.bigint   "vdi_desktop_pool_id"
      t.string   "vdi_desktop_pool_name"
      t.bigint   "service_id"
      t.bigint   "availability_zone_id"
    end

    add_index "ems_events", ["chain_id", "ems_id"], :name => "index_ems_events_on_chain_id_and_ems_id"
    add_index "ems_events", ["dest_host_id"], :name => "index_ems_events_on_dest_host_id"
    add_index "ems_events", ["dest_vm_or_template_id"], :name => "index_ems_events_on_dest_vm_id"
    add_index "ems_events", ["ems_cluster_id"], :name => "index_ems_events_on_ems_cluster_id"
    add_index "ems_events", ["ems_id"], :name => "index_ems_events_on_ems_id"
    add_index "ems_events", ["event_type"], :name => "index_ems_events_on_event_type"
    add_index "ems_events", ["host_id"], :name => "index_ems_events_on_host_id"
    add_index "ems_events", ["service_id"], :name => "index_ems_events_on_service_id"
    add_index "ems_events", ["timestamp"], :name => "index_ems_events_on_timestamp"
    add_index "ems_events", ["vm_or_template_id"], :name => "index_ems_events_on_vm_id"

    create_table "ems_folders" do |t|
      t.string   "name"
      t.boolean  "is_datacenter"
      t.bigint   "ems_id"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "uid_ems"
      t.string   "ems_ref_obj"
      t.string   "ems_ref"
    end

    add_index "ems_folders", ["ems_id"], :name => "index_ems_folders_on_ems_id"
    add_index "ems_folders", ["uid_ems"], :name => "index_ems_folders_on_uid"

    create_table "event_logs" do |t|
      t.string   "name"
      t.datetime "generated"
      t.text     "message"
      t.string   "uid"
      t.bigint   "event_id"
      t.string   "computer_name"
      t.string   "source"
      t.bigint   "operating_system_id"
      t.string   "level"
      t.string   "category"
    end

    add_index "event_logs", ["event_id"], :name => "index_event_logs_on_event_id"
    add_index "event_logs", ["operating_system_id"], :name => "index_event_logs_on_operating_system_id"

    create_table "ext_management_systems" do |t|
      t.string   "name"
      t.string   "port"
      t.string   "hostname"
      t.string   "ipaddress"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "guid",                        :limit => 36
      t.bigint   "zone_id"
      t.string   "type"
      t.string   "api_version"
      t.string   "uid_ems"
      t.integer  "host_default_vnc_port_start"
      t.integer  "host_default_vnc_port_end"
    end

    add_index "ext_management_systems", ["guid"], :name => "index_ext_management_systems_on_guid", :unique => true

    create_table "ext_management_systems_vdi_desktop_pools", :id => false do |t|
      t.bigint  "ems_id"
      t.bigint  "vdi_desktop_pool_id"
    end

    create_table "file_depots" do |t|
      t.string   "name"
      t.bigint   "resource_id"
      t.string   "resource_type"
      t.string   "uri"
      t.datetime "created_at",                 :null => false
      t.datetime "updated_at",                 :null => false
    end

    add_index "file_depots", ["resource_id", "resource_type"], :name => "index_file_depots_on_resource_id_and_resource_type"

    create_table "filesystems" do |t|
      t.text     "name"
      t.string   "md5"
      t.bigint   "size"
      t.datetime "atime"
      t.datetime "mtime"
      t.datetime "ctime"
      t.string   "rsc_type"
      t.text     "base_name"
      t.bigint   "miq_set_id"
      t.bigint   "scan_item_id"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "file_version"
      t.string   "product_version"
      t.string   "file_version_header"
      t.string   "product_version_header"
      t.string   "resource_type"
      t.bigint   "resource_id"
      t.string   "permissions"
      t.string   "owner"
      t.string   "group"
    end

    add_index "filesystems", ["miq_set_id"], :name => "index_filesystems_on_miq_set_id"
    add_index "filesystems", ["resource_id", "resource_type"], :name => "index_filesystems_on_resource_id_and_resource_type"
    add_index "filesystems", ["scan_item_id"], :name => "index_filesystems_on_scan_item_id"

    create_table "firewall_rules" do |t|
      t.string   "name"
      t.string   "display_name"
      t.string   "group"
      t.boolean  "enabled"
      t.boolean  "required"
      t.string   "protocol"
      t.string   "direction"
      t.integer  "port"
      t.integer  "end_port"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.bigint   "resource_id"
      t.string   "resource_type"
      t.bigint   "source_security_group_id"
      t.string   "source_ip_range"
    end

    add_index "firewall_rules", ["resource_id", "resource_type"], :name => "index_firewall_rules_on_resource_id_and_resource_type"

    create_table "flavors" do |t|
      t.bigint  "ems_id"
      t.string  "name"
      t.string  "description"
      t.integer "cpus"
      t.integer "cpu_cores"
      t.bigint  "memory"
      t.string  "ems_ref"
      t.string  "type"
      t.boolean "supports_32_bit"
      t.boolean "supports_64_bit"
      t.boolean "enabled"
    end

    add_index "flavors", ["ems_id"], :name => "index_flavors_on_ems_id"

    create_table "floating_ips" do |t|
      t.string  "type"
      t.string  "ems_ref"
      t.string  "address"
      t.bigint  "ems_id"
      t.bigint  "vm_id"
      t.boolean "cloud_network_only"
    end

    create_table "guest_applications" do |t|
      t.string  "name"
      t.string  "vendor"
      t.string  "version"
      t.text    "description"
      t.string  "package_name"
      t.string  "product_icon"
      t.string  "transform"
      t.integer "language"
      t.string  "typename"
      t.bigint  "vm_or_template_id"
      t.string  "product_key"
      t.string  "path",              :limit => 512
      t.string  "arch"
      t.bigint  "host_id"
      t.string  "release"
    end

    add_index "guest_applications", ["host_id"], :name => "index_guest_applications_on_host_id"
    add_index "guest_applications", ["typename"], :name => "index_guest_applications_on_typename"
    add_index "guest_applications", ["vm_or_template_id"], :name => "index_guest_applications_on_vm_id"

    create_table "guest_devices" do |t|
      t.string  "device_name"
      t.string  "device_type"
      t.string  "location"
      t.string  "filename"
      t.bigint  "hardware_id"
      t.string  "mode"
      t.string  "controller_type"
      t.bigint  "size"
      t.bigint  "free_space"
      t.bigint  "size_on_disk"
      t.string  "address"
      t.bigint  "switch_id"
      t.bigint  "lan_id"
      t.string  "model"
      t.string  "iscsi_name"
      t.string  "iscsi_alias"
      t.boolean "present",                        :default => true
      t.boolean "start_connected",                :default => true
      t.boolean "auto_detect"
      t.string  "uid_ems"
      t.boolean "chap_auth_enabled"
    end

    add_index "guest_devices", ["device_name"], :name => "index_guest_devices_on_device_name"
    add_index "guest_devices", ["device_type"], :name => "index_guest_devices_on_device_type"
    add_index "guest_devices", ["hardware_id"], :name => "index_guest_devices_on_hardware_id"
    add_index "guest_devices", ["lan_id"], :name => "index_guest_devices_on_lan_id"
    add_index "guest_devices", ["switch_id"], :name => "index_guest_devices_on_switch_id"

    create_table "hardwares" do |t|
      t.string  "config_version"
      t.string  "virtual_hw_version"
      t.string  "guest_os"
      t.integer "numvcpus",                        :default => 1
      t.string  "bios"
      t.string  "bios_location"
      t.string  "time_sync"
      t.text    "annotation"
      t.bigint  "vm_or_template_id"
      t.integer "memory_cpu"
      t.bigint  "host_id"
      t.integer "cpu_speed"
      t.string  "cpu_type"
      t.bigint  "size_on_disk"
      t.string  "manufacturer",                    :default => ""
      t.string  "model",                           :default => ""
      t.integer "number_of_nics"
      t.integer "cpu_usage"
      t.integer "memory_usage"
      t.integer "cores_per_socket"
      t.integer "logical_cpus"
      t.boolean "vmotion_enabled"
      t.bigint  "disk_free_space"
      t.bigint  "disk_capacity"
      t.string  "guest_os_full_name"
      t.integer "memory_console"
      t.integer "bitness"
    end

    add_index "hardwares", ["host_id"], :name => "index_hardwares_on_host_id"
    add_index "hardwares", ["vm_or_template_id"], :name => "index_hardwares_on_vm_id"

    create_table "hosts" do |t|
      t.string   "name"
      t.string   "hostname"
      t.string   "ipaddress"
      t.string   "vmm_vendor"
      t.string   "vmm_version"
      t.string   "vmm_product"
      t.string   "vmm_buildnumber"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "guid",                    :limit => 36
      t.bigint   "ems_id"
      t.string   "user_assigned_os"
      t.string   "power_state",                           :default => ""
      t.integer  "smart"
      t.string   "settings"
      t.datetime "last_perf_capture_on"
      t.string   "uid_ems"
      t.string   "connection_state"
      t.string   "ssh_permit_root_login"
      t.string   "ems_ref_obj"
      t.boolean  "admin_disabled"
      t.string   "service_tag"
      t.string   "asset_tag"
      t.string   "ipmi_address"
      t.string   "mac_address"
      t.string   "type"
      t.boolean  "failover"
      t.string   "ems_ref"
      t.boolean  "hyperthreading"
      t.bigint   "ems_cluster_id"
      t.integer  "next_available_vnc_port"
    end

    add_index "hosts", ["ems_id"], :name => "index_hosts_on_ems_id"
    add_index "hosts", ["guid"], :name => "index_hosts_on_guid", :unique => true
    add_index "hosts", ["hostname"], :name => "index_hosts_on_hostname"
    add_index "hosts", ["ipaddress"], :name => "index_hosts_on_ipaddress"

    create_table "hosts_storages", :id => false do |t|
      t.bigint  "storage_id"
      t.bigint  "host_id"
    end

    add_index "hosts_storages", ["host_id", "storage_id"], :name => "index_hosts_storages_on_host_id_and_storage_id", :unique => true

    create_table "iso_datastores" do |t|
      t.bigint   "ems_id"
      t.datetime "last_refresh_on"
    end

    create_table "iso_images" do |t|
      t.string  "name"
      t.bigint  "iso_datastore_id"
      t.bigint  "pxe_image_type_id"
    end

    create_table "jobs" do |t|
      t.string   "guid",            :limit => 36
      t.string   "state"
      t.string   "status"
      t.text     "message"
      t.string   "code"
      t.string   "name"
      t.string   "userid"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.bigint   "target_id"
      t.string   "target_class"
      t.string   "type"
      t.binary   "process"
      t.bigint   "agent_id"
      t.string   "agent_class"
      t.string   "agent_state"
      t.text     "agent_message"
      t.datetime "started_on"
      t.string   "dispatch_status"
      t.string   "sync_key"
      t.bigint   "miq_server_id"
      t.string   "zone"
      t.string   "agent_name"
      t.boolean  "archive"
      t.text     "options"
      t.text     "context"
    end

    add_index "jobs", ["agent_id", "agent_class"], :name => "index_jobs_on_agent_id_and_agent_class"
    add_index "jobs", ["dispatch_status"], :name => "index_jobs_on_dispatch_status"
    add_index "jobs", ["guid"], :name => "index_jobs_on_guid", :unique => true
    add_index "jobs", ["miq_server_id"], :name => "index_jobs_on_miq_server_id"
    add_index "jobs", ["state"], :name => "index_jobs_on_state"
    add_index "jobs", ["target_id", "target_class"], :name => "index_jobs_on_target_id_and_target_class"

    create_table "key_pairs_vms", :id => false do |t|
      t.bigint  "authentication_id"
      t.bigint  "vm_id"
    end

    create_table "lans" do |t|
      t.bigint   "switch_id"
      t.string   "name"
      t.string   "tag"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "uid_ems"
      t.boolean  "allow_promiscuous"
      t.boolean  "forged_transmits"
      t.boolean  "mac_changes"
      t.boolean  "computed_allow_promiscuous"
      t.boolean  "computed_forged_transmits"
      t.boolean  "computed_mac_changes"
    end

    add_index "lans", ["switch_id"], :name => "index_lans_on_switch_id"

    create_table "ldap_domains" do |t|
      t.string   "name"
      t.string   "base_dn"
      t.string   "user_type"
      t.string   "user_suffix"
      t.integer  "bind_timeout"
      t.integer  "search_timeout"
      t.integer  "group_membership_max_depth"
      t.boolean  "get_direct_groups"
      t.boolean  "follow_referrals"
      t.bigint   "ldap_domain_id"
      t.datetime "created_at",                              :null => false
      t.datetime "updated_at",                              :null => false
      t.datetime "last_user_sync"
      t.datetime "last_group_sync"
      t.boolean  "get_user_groups"
      t.boolean  "get_roles_from_home_forest"
      t.bigint   "ldap_region_id"
    end

    add_index "ldap_domains", ["ldap_region_id"], :name => "index_ldap_domains_on_ldap_region_id"

    create_table "ldap_groups" do |t|
      t.string   "dn"
      t.string   "display_name"
      t.string   "whencreated"
      t.string   "whenchanged"
      t.string   "mail"
      t.bigint   "ldap_domain_id"
      t.datetime "created_at",                  :null => false
      t.datetime "updated_at",                  :null => false
    end

    add_index "ldap_groups", ["ldap_domain_id"], :name => "index_ldap_groups_on_ldap_domain_id"

    create_table "ldap_managements" do |t|
      t.bigint  "manager_id"
      t.bigint  "ldap_user_id"
    end

    create_table "ldap_regions" do |t|
      t.string   "name"
      t.string   "description"
      t.bigint   "zone_id"
      t.datetime "created_at",               :null => false
      t.datetime "updated_at",               :null => false
    end

    add_index "ldap_regions", ["zone_id"], :name => "index_ldap_regions_on_zone_id"

    create_table "ldap_servers" do |t|
      t.string   "hostname"
      t.string   "mode"
      t.integer  "port"
      t.bigint   "ldap_domain_id"
      t.datetime "created_at",                  :null => false
      t.datetime "updated_at",                  :null => false
    end

    add_index "ldap_servers", ["ldap_domain_id"], :name => "index_ldap_servers_on_ldap_domain_id"

    create_table "ldap_users" do |t|
      t.string   "dn"
      t.string   "first_name"
      t.string   "last_name"
      t.string   "title"
      t.string   "display_name"
      t.string   "mail"
      t.string   "address"
      t.string   "city"
      t.string   "state"
      t.string   "zip"
      t.string   "country"
      t.string   "company"
      t.string   "department"
      t.string   "office"
      t.string   "phone"
      t.string   "phone_home"
      t.string   "phone_mobile"
      t.string   "fax"
      t.datetime "whencreated"
      t.datetime "whenchanged"
      t.string   "sid"
      t.bigint   "ldap_domain_id"
      t.datetime "created_at",                    :null => false
      t.datetime "updated_at",                    :null => false
      t.bigint   "vdi_user_id"
      t.string   "sam_account_name"
      t.string   "upn"
    end

    add_index "ldap_users", ["ldap_domain_id"], :name => "index_ldap_users_on_ldap_domain_id"

    create_table "lifecycle_events" do |t|
      t.string   "guid"
      t.string   "status"
      t.string   "event"
      t.string   "message"
      t.string   "location"
      t.bigint   "vm_or_template_id"
      t.string   "created_by"
      t.datetime "created_on"
    end

    add_index "lifecycle_events", ["guid"], :name => "index_lifecycle_events_on_guid", :unique => true
    add_index "lifecycle_events", ["vm_or_template_id"], :name => "index_lifecycle_events_on_vm_id"

    create_table "log_files" do |t|
      t.string   "name"
      t.string   "description"
      t.string   "resource_type"
      t.bigint   "resource_id"
      t.bigint   "miq_task_id"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.datetime "logging_started_on"
      t.datetime "logging_ended_on"
      t.string   "state"
      t.boolean  "historical"
      t.string   "log_uri"
    end

    add_index "log_files", ["miq_task_id"], :name => "index_log_files_on_miq_task_id"
    add_index "log_files", ["resource_id", "resource_type"], :name => "index_log_files_on_resource_id_and_resource_type"

    create_trigger_language # For metrics/metric_rollups inheritance triggers

    create_metrics_table "metrics"
    (0..23).each do |n|
      s = subtable_name("metrics", n)
      create_metrics_table  s
      add_metrics_indexes   s
      add_table_inheritance s, "metrics", :conditions => ["capture_interval_name = ? AND EXTRACT(HOUR FROM timestamp) = ?", "realtime", n]
    end
    add_metrics_inheritance_triggers

    create_metrics_table "metric_rollups"
    (1..12).each do |n|
      s = subtable_name("metric_rollups", n)
      create_metrics_table  s
      add_metrics_indexes   s
      add_table_inheritance s, "metric_rollups", :conditions => ["capture_interval_name != ? AND EXTRACT(MONTH FROM timestamp) = ?", "realtime", n]
    end
    add_metric_rollups_inheritance_triggers

    create_table "miq_actions" do |t|
      t.string   "name"
      t.string   "description"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "guid",        :limit => 36
      t.string   "action_type"
      t.text     "options"
    end

    add_index "miq_actions", ["guid"], :name => "index_miq_actions_on_guid", :unique => true

    create_table "miq_ae_classes" do |t|
      t.text     "description"
      t.string   "display_name"
      t.string   "name"
      t.string   "type"
      t.string   "inherits"
      t.string   "visibility"
      t.string   "owner"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.bigint   "namespace_id"
      t.string   "updated_by"
      t.bigint   "updated_by_user_id"
    end

    add_index "miq_ae_classes", ["namespace_id"], :name => "index_miq_ae_classes_on_namespace_id"
    add_index "miq_ae_classes", ["updated_by_user_id"], :name => "index_miq_ae_classes_on_updated_by_user_id"

    create_table "miq_ae_fields" do |t|
      t.string   "aetype"
      t.string   "name"
      t.string   "display_name"
      t.string   "datatype"
      t.integer  "priority"
      t.string   "owner"
      t.text     "default_value"
      t.boolean  "substitute",                      :default => true, :null => false
      t.text     "message"
      t.string   "visibility"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.bigint   "class_id"
      t.text     "collect"
      t.bigint   "method_id"
      t.string   "scope"
      t.text     "description"
      t.text     "condition"
      t.text     "on_entry"
      t.text     "on_exit"
      t.text     "on_error"
      t.string   "max_retries"
      t.string   "max_time"
      t.string   "updated_by"
      t.bigint   "updated_by_user_id"
    end

    add_index "miq_ae_fields", ["class_id"], :name => "index_miq_ae_fields_on_ae_class_id"
    add_index "miq_ae_fields", ["method_id"], :name => "index_miq_ae_fields_on_method_id"
    add_index "miq_ae_fields", ["updated_by_user_id"], :name => "index_miq_ae_fields_on_updated_by_user_id"

    create_table "miq_ae_instances" do |t|
      t.string   "display_name"
      t.string   "name"
      t.string   "inherits"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.bigint   "class_id"
      t.text     "description"
      t.string   "updated_by"
      t.bigint   "updated_by_user_id"
    end

    add_index "miq_ae_instances", ["class_id"], :name => "index_miq_ae_instances_on_ae_class_id"
    add_index "miq_ae_instances", ["updated_by_user_id"], :name => "index_miq_ae_instances_on_updated_by_user_id"

    create_table "miq_ae_methods" do |t|
      t.string   "name"
      t.bigint   "class_id"
      t.string   "display_name"
      t.text     "description"
      t.string   "scope"
      t.string   "language"
      t.string   "location"
      t.text     "data"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "updated_by"
      t.bigint   "updated_by_user_id"
    end

    add_index "miq_ae_methods", ["class_id"], :name => "index_miq_ae_methods_on_class_id"
    add_index "miq_ae_methods", ["updated_by_user_id"], :name => "index_miq_ae_methods_on_updated_by_user_id"

    create_table "miq_ae_namespaces" do |t|
      t.bigint   "parent_id"
      t.string   "name"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "description"
      t.string   "display_name"
      t.string   "updated_by"
      t.bigint   "updated_by_user_id"
    end

    add_index "miq_ae_namespaces", ["parent_id"], :name => "index_miq_ae_namespaces_on_parent_id"
    add_index "miq_ae_namespaces", ["updated_by_user_id"], :name => "index_miq_ae_namespaces_on_updated_by_user_id"

    create_table "miq_ae_values" do |t|
      t.bigint   "instance_id"
      t.bigint   "field_id"
      t.text     "value"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "display_name"
      t.text     "condition"
      t.text     "collect"
      t.text     "on_entry"
      t.text     "on_exit"
      t.text     "on_error"
      t.string   "max_retries"
      t.string   "max_time"
      t.string   "updated_by"
      t.bigint   "updated_by_user_id"
    end

    add_index "miq_ae_values", ["field_id"], :name => "index_miq_ae_values_on_field_id"
    add_index "miq_ae_values", ["instance_id"], :name => "index_miq_ae_values_on_instance_id"
    add_index "miq_ae_values", ["updated_by_user_id"], :name => "index_miq_ae_values_on_updated_by_user_id"

    create_table "miq_ae_workspaces" do |t|
      t.string   "guid",       :limit => 36
      t.text     "uri"
      t.text     "workspace"
      t.text     "setters"
      t.datetime "created_on"
      t.datetime "updated_on"
    end

    create_table "miq_alert_statuses" do |t|
      t.bigint   "miq_alert_id"
      t.bigint   "resource_id"
      t.string   "resource_type"
      t.datetime "evaluated_on"
      t.boolean  "result"
    end

    add_index "miq_alert_statuses", ["miq_alert_id"], :name => "index_miq_alert_statuses_on_miq_alert_id"
    add_index "miq_alert_statuses", ["resource_id", "resource_type"], :name => "index_miq_alert_statuses_on_resource_id_and_resource_type"

    create_table "miq_alerts" do |t|
      t.string   "guid",               :limit => 36
      t.string   "description"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "options"
      t.string   "db"
      t.text     "expression"
      t.text     "responds_to_events"
      t.boolean  "enabled"
    end

    create_table "miq_approvals" do |t|
      t.string   "description"
      t.string   "state"
      t.string   "reason"
      t.bigint   "miq_request_id"
      t.datetime "stamped_on"
      t.string   "stamper_name"
      t.bigint   "stamper_id"
      t.bigint   "approver_id"
      t.string   "approver_type"
      t.string   "approver_name"
      t.datetime "created_on"
      t.datetime "updated_on"
    end

    add_index "miq_approvals", ["approver_id", "approver_type"], :name => "index_miq_approvals_on_approver_id_and_approver_type"
    add_index "miq_approvals", ["miq_request_id"], :name => "index_miq_approvals_on_miq_request_id"
    add_index "miq_approvals", ["stamper_id"], :name => "index_miq_approvals_on_stamper_id"

    create_table "miq_cim_associations" do |t|
      t.string  "assoc_class"
      t.string  "result_class"
      t.string  "role"
      t.string  "result_role"
      t.string  "obj_name"
      t.string  "result_obj_name"
      t.bigint  "miq_cim_instance_id"
      t.bigint  "result_instance_id"
      t.integer "status"
      t.bigint  "zone_id"
    end

    add_index "miq_cim_associations", ["miq_cim_instance_id", "assoc_class", "role", "result_role"], :name => "index_on_miq_cim_associations_for_gen_query"
    add_index "miq_cim_associations", ["miq_cim_instance_id"], :name => "index_miq_cim_associations_on_miq_cim_instance_id"
    add_index "miq_cim_associations", ["obj_name", "result_obj_name", "assoc_class"], :name => "index_on_miq_cim_associations_for_point_to_point"
    add_index "miq_cim_associations", ["result_instance_id"], :name => "index_miq_cim_associations_on_result_instance_id"

    create_table "miq_cim_derived_metrics" do |t|
      t.datetime "statistic_time"
      t.integer  "interval"
      t.float    "k_bytes_read_per_sec"
      t.float    "read_ios_per_sec"
      t.float    "k_bytes_written_per_sec"
      t.float    "k_bytes_transferred_per_sec"
      t.float    "write_ios_per_sec"
      t.float    "write_hit_ios_per_sec"
      t.float    "read_hit_ios_per_sec"
      t.float    "total_ios_per_sec"
      t.float    "utilization"
      t.float    "response_time_sec"
      t.float    "queue_depth"
      t.float    "service_time_sec"
      t.float    "wait_time_sec"
      t.float    "avg_read_size"
      t.float    "avg_write_size"
      t.float    "pct_read"
      t.float    "pct_write"
      t.float    "pct_hit"
      t.bigint   "miq_storage_metric_id"
      t.datetime "created_at",                               :null => false
      t.datetime "updated_at",                               :null => false
    end

    add_index "miq_cim_derived_metrics", ["miq_storage_metric_id"], :name => "index_miq_cim_derived_metrics_on_miq_storage_metric_id"

    create_table "miq_cim_instances" do |t|
      t.string   "class_name"
      t.string   "class_hier",             :limit => 1024
      t.string   "namespace"
      t.string   "obj_name_str"
      t.text     "obj_name"
      t.text     "obj"
      t.integer  "last_update_status"
      t.boolean  "is_top_managed_element"
      t.bigint   "top_managed_element_id"
      t.bigint   "agent_top_id"
      t.bigint   "agent_id"
      t.bigint   "metric_id"
      t.bigint   "metric_top_id"
      t.datetime "created_at",                             :null => false
      t.datetime "updated_at",                             :null => false
      t.bigint   "vmdb_obj_id"
      t.string   "vmdb_obj_type"
      t.bigint   "zone_id"
      t.string   "source"
      t.string   "type"
      t.text     "type_spec_obj"
    end

    add_index "miq_cim_instances", ["agent_id"], :name => "index_miq_cim_instances_on_agent_id"
    add_index "miq_cim_instances", ["agent_top_id"], :name => "index_miq_cim_instances_on_agent_top_id"
    add_index "miq_cim_instances", ["metric_id"], :name => "index_miq_cim_instances_on_metric_id"
    add_index "miq_cim_instances", ["metric_top_id"], :name => "index_miq_cim_instances_on_metric_top_id"
    add_index "miq_cim_instances", ["obj_name_str"], :name => "index_miq_cim_instances_on_obj_name_str", :unique => true
    add_index "miq_cim_instances", ["top_managed_element_id"], :name => "index_miq_cim_instances_on_top_managed_element_id"
    add_index "miq_cim_instances", ["type"], :name => "index_miq_cim_instances_on_type"

    create_table "miq_databases" do |t|
      t.datetime "created_at",                                    :null => false
      t.datetime "updated_at",                                    :null => false
      t.bigint   "last_replication_count"
      t.bigint   "last_replication_id"
      t.string   "registration_type"
      t.string   "registration_organization"
      t.string   "registration_server"
      t.string   "registration_http_proxy_server"
      t.string   "registration_http_proxy_username"
      t.string   "registration_http_proxy_password"
      t.string   "cfme_version_available"
      t.boolean  "postgres_update_available"
      t.string   "session_secret_token"
      t.string   "csrf_secret_token"
    end

    create_table "miq_dialogs" do |t|
      t.string   "name"
      t.string   "description"
      t.string   "dialog_type"
      t.text     "content"
      t.boolean  "default",     :default => false
      t.string   "filename"
      t.datetime "file_mtime"
      t.datetime "created_at",                     :null => false
      t.datetime "updated_at",                     :null => false
    end

    create_table "miq_enterprises" do |t|
      t.string   "name"
      t.string   "description"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "settings"
    end

    create_table "miq_events" do |t|
      t.string   "name"
      t.string   "description"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "guid",        :limit => 36
      t.string   "event_type"
      t.text     "definition"
      t.boolean  "default"
      t.boolean  "enabled"
    end

    add_index "miq_events", ["guid"], :name => "index_miq_events_on_guid", :unique => true

    create_table "miq_globals" do |t|
      t.string   "section"
      t.string   "key"
      t.text     "value"
      t.string   "description"
      t.datetime "created_on"
      t.datetime "updated_on"
    end

    create_table "miq_groups" do |t|
      t.string   "guid",             :limit => 36
      t.string   "description"
      t.bigint   "ui_task_set_id"
      t.string   "group_type"
      t.integer  "sequence"
      t.string   "resource_type"
      t.bigint   "resource_id"
      t.text     "filters"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.bigint   "miq_user_role_id"
      t.text     "settings"
    end

    add_index "miq_groups", ["miq_user_role_id"], :name => "index_miq_groups_on_miq_user_role_id"
    add_index "miq_groups", ["resource_id", "resource_type"], :name => "index_miq_groups_on_resource_id_and_resource_type"
    add_index "miq_groups", ["ui_task_set_id"], :name => "index_miq_groups_on_ui_task_set_id"

    create_table "miq_license_contents" do |t|
      t.text     "contents"
      t.boolean  "active"
      t.datetime "created_on"
      t.datetime "updated_on"
    end

    create_table "miq_policies" do |t|
      t.string   "name"
      t.string   "description"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "expression"
      t.string   "towhat"
      t.string   "guid",        :limit => 36
      t.string   "created_by"
      t.string   "updated_by"
      t.string   "notes",       :limit => 512
      t.boolean  "active"
      t.string   "mode"
    end

    create_table "miq_policy_contents" do |t|
      t.bigint   "miq_policy_id"
      t.bigint   "miq_action_id"
      t.bigint   "miq_event_id"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "qualifier"
      t.integer  "success_sequence"
      t.integer  "failure_sequence"
      t.boolean  "success_synchronous"
      t.boolean  "failure_synchronous"
    end

    add_index "miq_policy_contents", ["miq_action_id"], :name => "index_miq_policy_contents_on_miq_action_id"
    add_index "miq_policy_contents", ["miq_event_id"], :name => "index_miq_policy_contents_on_miq_event_id"
    add_index "miq_policy_contents", ["miq_policy_id"], :name => "index_miq_policy_contents_on_miq_policy_id"

    create_table "miq_product_features" do |t|
      t.string   "identifier"
      t.string   "name"
      t.string   "description"
      t.string   "feature_type"
      t.boolean  "protected",                 :default => false
      t.bigint   "parent_id"
      t.datetime "created_at",                                   :null => false
      t.datetime "updated_at",                                   :null => false
    end

    add_index "miq_product_features", ["parent_id"], :name => "index_miq_product_features_on_parent_id"

    create_table "miq_proxies" do |t|
      t.string   "guid",             :limit => 36
      t.string   "name"
      t.text     "settings"
      t.datetime "last_heartbeat"
      t.string   "version"
      t.string   "ws_port"
      t.bigint   "host_id"
      t.bigint   "vm_id"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "capabilities"
      t.string   "power_state"
      t.string   "upgrade_status"
      t.string   "upgrade_message"
      t.text     "remote_config"
      t.string   "upgrade_settings"
      t.bigint   "vdi_farm_id"
    end

    add_index "miq_proxies", ["guid"], :name => "index_miq_proxies_on_guid", :unique => true
    add_index "miq_proxies", ["host_id"], :name => "index_miq_proxies_on_host_id"
    add_index "miq_proxies", ["vdi_farm_id"], :name => "index_miq_proxies_on_vdi_farm_id"
    add_index "miq_proxies", ["vm_id"], :name => "index_miq_proxies_on_vm_id"

    create_table "miq_proxies_product_updates", :id => false do |t|
      t.bigint  "product_update_id"
      t.bigint  "miq_proxy_id"
    end

    create_table "miq_queue" do |t|
      t.bigint   "target_id"
      t.integer  "priority"
      t.string   "method_name"
      t.string   "state"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.integer  "lock_version",               :default => 0
      t.string   "task_id"
      t.string   "md5"
      t.datetime "deliver_on"
      t.string   "queue_name"
      t.string   "class_name"
      t.bigint   "instance_id"
      t.text     "args"
      t.text     "miq_callback"
      t.binary   "msg_data"
      t.string   "zone"
      t.string   "role"
      t.string   "server_guid",  :limit => 36
      t.integer  "msg_timeout"
      t.bigint   "handler_id"
      t.string   "handler_type"
      t.string   "for_user"
      t.bigint   "for_user_id"
      t.datetime "expires_on"
    end

    add_index "miq_queue", ["state", "zone", "task_id", "queue_name", "role", "server_guid", "deliver_on", "priority", "id"], :name => "miq_queue_idx"

    create_table "miq_regions" do |t|
      t.integer  "region"
      t.datetime "created_at",                :null => false
      t.datetime "updated_at",                :null => false
      t.string   "description"
      t.string   "guid",        :limit => 36
    end

    create_table "miq_report_result_details" do |t|
      t.bigint  "miq_report_result_id"
      t.string  "data_type"
      t.text    "data"
    end

    add_index "miq_report_result_details", ["miq_report_result_id", "data_type", "id"], :name => "miq_report_result_details_idx"

    create_table "miq_report_results" do |t|
      t.string   "name"
      t.bigint   "miq_report_id"
      t.bigint   "miq_task_id"
      t.string   "userid"
      t.string   "report_source"
      t.string   "db"
      t.text     "report"
      t.datetime "created_on"
      t.datetime "scheduled_on"
      t.datetime "last_run_on"
      t.datetime "last_accessed_on"
      t.integer  "report_rows_per_detail_row"
      t.bigint   "miq_group_id"
    end

    add_index "miq_report_results", ["miq_group_id"], :name => "index_miq_report_results_on_miq_group_id"
    add_index "miq_report_results", ["miq_report_id"], :name => "index_miq_report_results_on_miq_report_id"
    add_index "miq_report_results", ["miq_task_id"], :name => "index_miq_report_results_on_miq_task_id"

    create_table "miq_reports" do |t|
      t.string   "name"
      t.string   "title"
      t.string   "rpt_group"
      t.string   "rpt_type"
      t.integer  "priority"
      t.string   "db"
      t.text     "cols"
      t.text     "include"
      t.text     "col_order"
      t.text     "headers"
      t.text     "conditions"
      t.string   "order"
      t.string   "sortby"
      t.string   "group"
      t.string   "graph"
      t.integer  "dims"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "filename"
      t.datetime "file_mtime"
      t.text     "categories"
      t.text     "timeline"
      t.string   "template_type"
      t.string   "where_clause"
      t.text     "db_options"
      t.text     "generate_cols"
      t.text     "generate_rows"
      t.text     "col_formats"
      t.string   "tz"
      t.bigint   "time_profile_id"
      t.text     "display_filter"
      t.text     "col_options"
      t.text     "rpt_options"
      t.bigint   "miq_group_id"
      t.bigint   "user_id"
    end

    add_index "miq_reports", ["db"], :name => "index_miq_reports_on_db"
    add_index "miq_reports", ["miq_group_id"], :name => "index_miq_reports_on_miq_group_id"
    add_index "miq_reports", ["rpt_type"], :name => "index_miq_reports_on_rpt_type"
    add_index "miq_reports", ["template_type"], :name => "index_miq_reports_on_template_type"
    add_index "miq_reports", ["time_profile_id"], :name => "index_miq_reports_on_time_profile_id"

    create_table "miq_request_tasks" do |t|
      t.string   "description"
      t.string   "state"
      t.string   "request_type"
      t.string   "userid"
      t.text     "options"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "message"
      t.string   "status"
      t.string   "type"
      t.bigint   "miq_request_id"
      t.bigint   "source_id"
      t.string   "source_type"
      t.bigint   "destination_id"
      t.string   "destination_type"
      t.bigint   "miq_request_task_id"
      t.string   "phase"
      t.text     "phase_context"
    end

    add_index "miq_request_tasks", ["destination_id", "destination_type"], :name => "index_miq_request_tasks_on_destination_id_and_destination_type"
    add_index "miq_request_tasks", ["miq_request_id"], :name => "index_miq_request_tasks_on_miq_request_id"
    add_index "miq_request_tasks", ["source_id", "source_type"], :name => "index_miq_request_tasks_on_source_id_and_source_type"

    create_table "miq_requests" do |t|
      t.string   "description"
      t.string   "approval_state"
      t.string   "type"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.datetime "fulfilled_on"
      t.bigint   "requester_id"
      t.string   "requester_name"
      t.string   "request_type"
      t.string   "request_state"
      t.string   "message"
      t.string   "status"
      t.text     "options"
      t.string   "userid"
      t.bigint   "source_id"
      t.string   "source_type"
      t.bigint   "destination_id"
      t.string   "destination_type"
    end

    add_index "miq_requests", ["destination_id", "destination_type"], :name => "index_miq_requests_on_destination_id_and_destination_type"
    add_index "miq_requests", ["requester_id"], :name => "index_miq_requests_on_requester_id"
    add_index "miq_requests", ["source_id", "source_type"], :name => "index_miq_requests_on_source_id_and_source_type"

    create_table "miq_roles_features", :id => false do |t|
      t.bigint  "miq_user_role_id"
      t.bigint  "miq_product_feature_id"
    end

    create_table "miq_schedules" do |t|
      t.string   "name"
      t.string   "description"
      t.text     "sched_action"
      t.text     "filter"
      t.string   "towhat"
      t.text     "run_at"
      t.boolean  "enabled"
      t.string   "userid"
      t.string   "prod_default"
      t.datetime "last_run_on"
      t.datetime "created_on"
      t.datetime "updated_at"
      t.bigint   "miq_search_id"
      t.bigint   "zone_id"
      t.boolean  "adhoc"
    end

    add_index "miq_schedules", ["miq_search_id"], :name => "index_miq_schedules_on_miq_search_id"
    add_index "miq_schedules", ["zone_id"], :name => "index_miq_schedules_on_zone_id"

    create_table "miq_scsi_luns" do |t|
      t.bigint  "miq_scsi_target_id"
      t.integer "lun"
      t.string  "canonical_name"
      t.string  "lun_type"
      t.string  "device_name"
      t.bigint  "block"
      t.integer "block_size"
      t.bigint  "capacity"
      t.string  "device_type"
      t.string  "uid_ems"
    end

    add_index "miq_scsi_luns", ["miq_scsi_target_id"], :name => "index_miq_scsi_luns_on_miq_scsi_target_id"

    create_table "miq_scsi_targets" do |t|
      t.bigint  "guest_device_id"
      t.integer "target"
      t.string  "iscsi_name"
      t.string  "iscsi_alias"
      t.string  "address"
      t.string  "uid_ems"
    end

    add_index "miq_scsi_targets", ["guest_device_id"], :name => "index_miq_scsi_targets_on_guest_device_id"

    create_table "miq_searches" do |t|
      t.string "name"
      t.string "description"
      t.text   "options"
      t.text   "filter"
      t.string "db"
      t.string "search_type"
      t.string "search_key"
    end

    create_table "miq_servers" do |t|
      t.string   "guid",                     :limit => 36
      t.string   "status"
      t.datetime "started_on"
      t.datetime "stopped_on"
      t.integer  "pid"
      t.string   "build"
      t.float    "percent_memory"
      t.float    "percent_cpu"
      t.float    "cpu_time"
      t.string   "name"
      t.text     "capabilities"
      t.datetime "last_heartbeat"
      t.integer  "os_priority"
      t.boolean  "is_master",                                                             :default => false
      t.binary   "logo"
      t.string   "version"
      t.bigint   "zone_id"
      t.string   "upgrade_status"
      t.string   "upgrade_message"
      t.decimal  "memory_usage",                           :precision => 20, :scale => 0
      t.decimal  "memory_size",                            :precision => 20, :scale => 0
      t.string   "hostname"
      t.string   "ipaddress"
      t.string   "drb_uri"
      t.string   "mac_address"
      t.bigint   "vm_id"
      t.boolean  "has_active_userinterface"
      t.boolean  "has_active_webservices"
      t.integer  "sql_spid"
      t.boolean  "rh_registered"
      t.boolean  "rh_subscribed"
      t.string   "last_update_check"
      t.boolean  "updates_available"
      t.boolean  "rhn_mirror"
    end

    add_index "miq_servers", ["guid"], :name => "index_miq_servers_on_guid", :unique => true
    add_index "miq_servers", ["vm_id"], :name => "index_miq_servers_on_vm_id"
    add_index "miq_servers", ["zone_id"], :name => "index_miq_servers_on_zone_id"

    create_table "miq_servers_product_updates", :id => false do |t|
      t.bigint  "product_update_id"
      t.bigint  "miq_server_id"
    end

    create_table "miq_sets" do |t|
      t.string   "name"
      t.string   "description"
      t.string   "set_type"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "guid",        :limit => 36
      t.boolean  "read_only"
      t.text     "set_data"
      t.string   "mode"
      t.string   "owner_type"
      t.bigint   "owner_id"
    end

    add_index "miq_sets", ["guid"], :name => "index_miq_sets_on_guid", :unique => true
    add_index "miq_sets", ["name"], :name => "index_miq_sets_on_name"
    add_index "miq_sets", ["owner_id", "owner_type"], :name => "index_miq_sets_on_owner_id_and_owner_type"
    add_index "miq_sets", ["set_type"], :name => "index_miq_sets_on_set_type"

    create_table "miq_shortcuts" do |t|
      t.string  "name"
      t.string  "description"
      t.string  "url"
      t.string  "rbac_feature_name"
      t.boolean "startup"
      t.integer "sequence"
    end

    create_table "miq_storage_metrics" do |t|
      t.text     "metric_obj"
      t.datetime "created_at", :null => false
      t.datetime "updated_at", :null => false
      t.string   "type"
    end

    create_table "miq_tasks" do |t|
      t.string   "name"
      t.string   "state"
      t.string   "status"
      t.string   "message"
      t.string   "userid"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.integer  "pct_complete"
      t.text     "context_data"
      t.text     "results"
      t.bigint   "miq_server_id"
      t.string   "identifier"
    end

    add_index "miq_tasks", ["miq_server_id"], :name => "index_miq_tasks_on_miq_server_id"

    create_table "miq_user_roles" do |t|
      t.string   "name"
      t.boolean  "read_only"
      t.datetime "created_at", :null => false
      t.datetime "updated_at", :null => false
      t.text     "settings"
    end

    create_table "miq_widget_contents" do |t|
      t.bigint   "miq_widget_id"
      t.bigint   "miq_report_result_id"
      t.text     "contents"
      t.datetime "created_at",                        :null => false
      t.datetime "updated_at",                        :null => false
      t.bigint   "owner_id"
      t.string   "owner_type"
      t.string   "timezone"
    end

    add_index "miq_widget_contents", ["miq_report_result_id"], :name => "index_miq_widget_contents_on_miq_report_result_id"
    add_index "miq_widget_contents", ["miq_widget_id"], :name => "index_miq_widget_contents_on_miq_widget_id"
    add_index "miq_widget_contents", ["owner_id"], :name => "index_miq_widget_contents_on_owner_id"

    create_table "miq_widget_shortcuts" do |t|
      t.string  "description"
      t.bigint  "miq_shortcut_id"
      t.bigint  "miq_widget_id"
      t.integer "sequence"
    end

    create_table "miq_widgets" do |t|
      t.string   "guid",                      :limit => 36
      t.string   "description"
      t.string   "title"
      t.string   "content_type"
      t.text     "options"
      t.text     "visibility"
      t.bigint   "user_id"
      t.bigint   "resource_id"
      t.string   "resource_type"
      t.bigint   "miq_schedule_id"
      t.boolean  "enabled"
      t.boolean  "read_only"
      t.datetime "created_at",                              :null => false
      t.datetime "updated_at",                              :null => false
      t.datetime "last_generated_content_on"
      t.bigint   "miq_task_id"
    end

    add_index "miq_widgets", ["miq_schedule_id"], :name => "index_miq_widgets_on_miq_schedule_id"
    add_index "miq_widgets", ["miq_task_id"], :name => "index_miq_widgets_on_miq_task_id"
    add_index "miq_widgets", ["resource_id", "resource_type"], :name => "index_miq_widgets_on_resource_id_and_resource_type"
    add_index "miq_widgets", ["user_id"], :name => "index_miq_widgets_on_user_id"

    create_table "miq_workers" do |t|
      t.string   "guid",           :limit => 36
      t.string   "status"
      t.datetime "started_on"
      t.datetime "stopped_on"
      t.datetime "last_heartbeat"
      t.integer  "pid"
      t.string   "queue_name"
      t.string   "type"
      t.string   "command_line",   :limit => 512
      t.float    "percent_memory"
      t.float    "percent_cpu"
      t.float    "cpu_time"
      t.integer  "os_priority"
      t.decimal  "memory_usage",                  :precision => 20, :scale => 0
      t.decimal  "memory_size",                   :precision => 20, :scale => 0
      t.string   "uri"
      t.bigint   "miq_server_id"
      t.integer  "sql_spid"
    end

    add_index "miq_workers", ["guid"], :name => "index_miq_workers_on_guid", :unique => true
    add_index "miq_workers", ["miq_server_id"], :name => "index_miq_workers_on_miq_server_id"
    add_index "miq_workers", ["queue_name"], :name => "index_miq_workers_on_queue_name"
    add_index "miq_workers", ["status"], :name => "index_miq_workers_on_status"
    add_index "miq_workers", ["type"], :name => "index_miq_workers_on_worker_type"

    create_table "networks" do |t|
      t.bigint   "hardware_id"
      t.bigint   "device_id"
      t.string   "description"
      t.string   "guid",            :limit => 36
      t.boolean  "dhcp_enabled"
      t.string   "ipaddress"
      t.string   "subnet_mask"
      t.datetime "lease_obtained"
      t.datetime "lease_expires"
      t.string   "default_gateway"
      t.string   "dhcp_server"
      t.string   "dns_server"
      t.string   "hostname"
      t.string   "domain"
      t.string   "ipv6address"
    end

    add_index "networks", ["device_id"], :name => "index_networks_on_device_id"
    add_index "networks", ["hardware_id"], :name => "index_networks_on_hardware_id"

    create_table "ontap_aggregate_derived_metrics" do |t|
      t.datetime "statistic_time"
      t.integer  "interval"
      t.float    "total_transfers"
      t.float    "user_reads"
      t.float    "user_writes"
      t.float    "cp_reads"
      t.float    "user_read_blocks"
      t.float    "user_write_blocks"
      t.float    "cp_read_blocks"
      t.bigint   "miq_storage_metric_id"
      t.datetime "created_at",                               :null => false
      t.datetime "updated_at",                               :null => false
      t.text     "base_counters"
      t.bigint   "miq_cim_instance_id"
      t.bigint   "storage_metrics_metadata_id"
    end

    add_index "ontap_aggregate_derived_metrics", ["miq_cim_instance_id"], :name => "index_ontap_aggregate_derived_metrics_on_miq_cim_instance_id"
    add_index "ontap_aggregate_derived_metrics", ["miq_storage_metric_id"], :name => "index_ontap_aggregate_derived_metrics_on_miq_storage_metric_id"
    add_index "ontap_aggregate_derived_metrics", ["storage_metrics_metadata_id"], :name => "index_ontap_aggregate_derived_metrics_on_smm_id"

    create_table "ontap_aggregate_metrics_rollups" do |t|
      t.datetime "statistic_time"
      t.string   "rollup_type"
      t.bigint   "interval"
      t.float    "total_transfers"
      t.float    "total_transfers_min"
      t.float    "total_transfers_max"
      t.float    "user_reads"
      t.float    "user_reads_min"
      t.float    "user_reads_max"
      t.float    "user_writes"
      t.float    "user_writes_min"
      t.float    "user_writes_max"
      t.float    "cp_reads"
      t.float    "cp_reads_min"
      t.float    "cp_reads_max"
      t.float    "user_read_blocks"
      t.float    "user_read_blocks_min"
      t.float    "user_read_blocks_max"
      t.float    "user_write_blocks"
      t.float    "user_write_blocks_min"
      t.float    "user_write_blocks_max"
      t.float    "cp_read_blocks"
      t.float    "cp_read_blocks_min"
      t.float    "cp_read_blocks_max"
      t.text     "base_counters"
      t.bigint   "miq_storage_metric_id"
      t.bigint   "time_profile_id"
      t.datetime "created_at",                               :null => false
      t.datetime "updated_at",                               :null => false
      t.bigint   "miq_cim_instance_id"
      t.bigint   "storage_metrics_metadata_id"
    end

    add_index "ontap_aggregate_metrics_rollups", ["miq_cim_instance_id"], :name => "index_ontap_aggregate_metrics_rollups_on_miq_cim_instance_id"
    add_index "ontap_aggregate_metrics_rollups", ["miq_storage_metric_id"], :name => "index_ontap_aggregate_metrics_rollups_on_miq_storage_metric_id"
    add_index "ontap_aggregate_metrics_rollups", ["storage_metrics_metadata_id"], :name => "index_ontap_aggregate_metrics_rollups_on_smm_id"
    add_index "ontap_aggregate_metrics_rollups", ["time_profile_id"], :name => "index_ontap_aggregate_metrics_rollups_on_time_profile_id"

    create_table "ontap_disk_derived_metrics" do |t|
      t.datetime "statistic_time"
      t.integer  "interval"
      t.float    "total_transfers"
      t.float    "user_read_chain"
      t.float    "user_reads"
      t.float    "user_write_chain"
      t.float    "user_writes"
      t.float    "user_writes_in_skip_mask"
      t.float    "user_skip_write_ios"
      t.float    "cp_read_chain"
      t.float    "cp_reads"
      t.float    "guarenteed_read_chain"
      t.float    "guarenteed_reads"
      t.float    "guarenteed_write_chain"
      t.float    "guarenteed_writes"
      t.float    "user_read_latency"
      t.float    "user_read_blocks"
      t.float    "user_write_latency"
      t.float    "user_write_blocks"
      t.float    "skip_blocks"
      t.float    "cp_read_latency"
      t.float    "cp_read_blocks"
      t.float    "guarenteed_read_latency"
      t.float    "guarenteed_read_blocks"
      t.float    "guarenteed_write_latency"
      t.float    "guarenteed_write_blocks"
      t.float    "disk_busy"
      t.float    "io_pending"
      t.float    "io_queued"
      t.bigint   "miq_storage_metric_id"
      t.datetime "created_at",                               :null => false
      t.datetime "updated_at",                               :null => false
      t.text     "base_counters"
      t.bigint   "miq_cim_instance_id"
      t.bigint   "storage_metrics_metadata_id"
    end

    add_index "ontap_disk_derived_metrics", ["miq_cim_instance_id"], :name => "index_ontap_disk_derived_metrics_on_miq_cim_instance_id"
    add_index "ontap_disk_derived_metrics", ["miq_storage_metric_id"], :name => "index_ontap_disk_derived_metrics_on_miq_storage_metric_id"
    add_index "ontap_disk_derived_metrics", ["storage_metrics_metadata_id"], :name => "index_ontap_disk_derived_metrics_on_smm_id"

    create_table "ontap_disk_metrics_rollups" do |t|
      t.datetime "statistic_time"
      t.string   "rollup_type"
      t.bigint   "interval"
      t.float    "total_transfers"
      t.float    "total_transfers_min"
      t.float    "total_transfers_max"
      t.float    "user_read_chain"
      t.float    "user_read_chain_min"
      t.float    "user_read_chain_max"
      t.float    "user_reads"
      t.float    "user_reads_min"
      t.float    "user_reads_max"
      t.float    "user_write_chain"
      t.float    "user_write_chain_min"
      t.float    "user_write_chain_max"
      t.float    "user_writes"
      t.float    "user_writes_min"
      t.float    "user_writes_max"
      t.float    "user_writes_in_skip_mask"
      t.float    "user_writes_in_skip_mask_min"
      t.float    "user_writes_in_skip_mask_max"
      t.float    "user_skip_write_ios"
      t.float    "user_skip_write_ios_min"
      t.float    "user_skip_write_ios_max"
      t.float    "cp_read_chain"
      t.float    "cp_read_chain_min"
      t.float    "cp_read_chain_max"
      t.float    "cp_reads"
      t.float    "cp_reads_min"
      t.float    "cp_reads_max"
      t.float    "guarenteed_read_chain"
      t.float    "guarenteed_read_chain_min"
      t.float    "guarenteed_read_chain_max"
      t.float    "guarenteed_reads"
      t.float    "guarenteed_reads_min"
      t.float    "guarenteed_reads_max"
      t.float    "guarenteed_write_chain"
      t.float    "guarenteed_write_chain_min"
      t.float    "guarenteed_write_chain_max"
      t.float    "guarenteed_writes"
      t.float    "guarenteed_writes_min"
      t.float    "guarenteed_writes_max"
      t.float    "user_read_latency"
      t.float    "user_read_latency_min"
      t.float    "user_read_latency_max"
      t.float    "user_read_blocks"
      t.float    "user_read_blocks_min"
      t.float    "user_read_blocks_max"
      t.float    "user_write_latency"
      t.float    "user_write_latency_min"
      t.float    "user_write_latency_max"
      t.float    "user_write_blocks"
      t.float    "user_write_blocks_min"
      t.float    "user_write_blocks_max"
      t.float    "skip_blocks"
      t.float    "skip_blocks_min"
      t.float    "skip_blocks_max"
      t.float    "cp_read_latency"
      t.float    "cp_read_latency_min"
      t.float    "cp_read_latency_max"
      t.float    "cp_read_blocks"
      t.float    "cp_read_blocks_min"
      t.float    "cp_read_blocks_max"
      t.float    "guarenteed_read_latency"
      t.float    "guarenteed_read_latency_min"
      t.float    "guarenteed_read_latency_max"
      t.float    "guarenteed_read_blocks"
      t.float    "guarenteed_read_blocks_min"
      t.float    "guarenteed_read_blocks_max"
      t.float    "guarenteed_write_latency"
      t.float    "guarenteed_write_latency_min"
      t.float    "guarenteed_write_latency_max"
      t.float    "guarenteed_write_blocks"
      t.float    "guarenteed_write_blocks_min"
      t.float    "guarenteed_write_blocks_max"
      t.float    "disk_busy"
      t.float    "disk_busy_min"
      t.float    "disk_busy_max"
      t.float    "io_pending"
      t.float    "io_pending_min"
      t.float    "io_pending_max"
      t.float    "io_queued"
      t.float    "io_queued_min"
      t.float    "io_queued_max"
      t.text     "base_counters"
      t.bigint   "miq_storage_metric_id"
      t.bigint   "time_profile_id"
      t.datetime "created_at",                                :null => false
      t.datetime "updated_at",                                :null => false
      t.bigint   "miq_cim_instance_id"
      t.bigint   "storage_metrics_metadata_id"
    end

    add_index "ontap_disk_metrics_rollups", ["miq_cim_instance_id"], :name => "index_ontap_disk_metrics_rollups_on_miq_cim_instance_id"
    add_index "ontap_disk_metrics_rollups", ["miq_storage_metric_id"], :name => "index_ontap_disk_metrics_rollups_on_miq_storage_metric_id"
    add_index "ontap_disk_metrics_rollups", ["storage_metrics_metadata_id"], :name => "index_ontap_disk_metrics_rollups_on_smm_id"
    add_index "ontap_disk_metrics_rollups", ["time_profile_id"], :name => "index_ontap_disk_metrics_rollups_on_time_profile_id"

    create_table "ontap_lun_derived_metrics" do |t|
      t.datetime "statistic_time"
      t.integer  "interval"
      t.float    "read_ops"
      t.float    "write_ops"
      t.float    "other_ops"
      t.float    "total_ops"
      t.float    "read_data"
      t.float    "write_data"
      t.float    "queue_full"
      t.float    "avg_latency"
      t.bigint   "miq_storage_metric_id"
      t.datetime "created_at",                               :null => false
      t.datetime "updated_at",                               :null => false
      t.text     "base_counters"
      t.bigint   "miq_cim_instance_id"
      t.bigint   "storage_metrics_metadata_id"
    end

    add_index "ontap_lun_derived_metrics", ["miq_cim_instance_id"], :name => "index_ontap_lun_derived_metrics_on_miq_cim_instance_id"
    add_index "ontap_lun_derived_metrics", ["miq_storage_metric_id"], :name => "index_ontap_lun_derived_metrics_on_miq_storage_metric_id"
    add_index "ontap_lun_derived_metrics", ["storage_metrics_metadata_id"], :name => "index_ontap_lun_derived_metrics_on_smm_id"

    create_table "ontap_lun_metrics_rollups" do |t|
      t.datetime "statistic_time"
      t.string   "rollup_type"
      t.bigint   "interval"
      t.float    "read_ops"
      t.float    "read_ops_min"
      t.float    "read_ops_max"
      t.float    "write_ops"
      t.float    "write_ops_min"
      t.float    "write_ops_max"
      t.float    "other_ops"
      t.float    "other_ops_min"
      t.float    "other_ops_max"
      t.float    "total_ops"
      t.float    "total_ops_min"
      t.float    "total_ops_max"
      t.float    "read_data"
      t.float    "read_data_min"
      t.float    "read_data_max"
      t.float    "write_data"
      t.float    "write_data_min"
      t.float    "write_data_max"
      t.float    "queue_full"
      t.float    "queue_full_min"
      t.float    "queue_full_max"
      t.float    "avg_latency"
      t.float    "avg_latency_min"
      t.float    "avg_latency_max"
      t.text     "base_counters"
      t.bigint   "miq_storage_metric_id"
      t.bigint   "time_profile_id"
      t.datetime "created_at",                               :null => false
      t.datetime "updated_at",                               :null => false
      t.bigint   "miq_cim_instance_id"
      t.bigint   "storage_metrics_metadata_id"
    end

    add_index "ontap_lun_metrics_rollups", ["miq_cim_instance_id"], :name => "index_ontap_lun_metrics_rollups_on_miq_cim_instance_id"
    add_index "ontap_lun_metrics_rollups", ["miq_storage_metric_id"], :name => "index_ontap_lun_metrics_rollups_on_miq_storage_metric_id"
    add_index "ontap_lun_metrics_rollups", ["storage_metrics_metadata_id"], :name => "index_ontap_lun_metrics_rollups_on_smm_id"
    add_index "ontap_lun_metrics_rollups", ["time_profile_id"], :name => "index_ontap_lun_metrics_rollups_on_time_profile_id"

    create_table "ontap_system_derived_metrics" do |t|
      t.datetime "statistic_time"
      t.integer  "interval"
      t.float    "cpu_busy"
      t.float    "avg_processor_busy"
      t.float    "total_processor_busy"
      t.float    "read_ops"
      t.float    "write_ops"
      t.float    "total_ops"
      t.float    "sys_read_latency"
      t.float    "sys_write_latency"
      t.float    "sys_avg_latency"
      t.float    "nfs_ops"
      t.float    "cifs_ops"
      t.float    "http_ops"
      t.float    "fcp_ops"
      t.float    "iscsi_ops"
      t.float    "net_data_recv"
      t.float    "net_data_sent"
      t.float    "disk_data_read"
      t.float    "disk_data_written"
      t.bigint   "miq_storage_metric_id"
      t.datetime "created_at",                               :null => false
      t.datetime "updated_at",                               :null => false
      t.text     "base_counters"
      t.bigint   "miq_cim_instance_id"
      t.bigint   "storage_metrics_metadata_id"
    end

    add_index "ontap_system_derived_metrics", ["miq_cim_instance_id"], :name => "index_ontap_system_derived_metrics_on_miq_cim_instance_id"
    add_index "ontap_system_derived_metrics", ["miq_storage_metric_id"], :name => "index_ontap_system_derived_metrics_on_miq_storage_metric_id"
    add_index "ontap_system_derived_metrics", ["storage_metrics_metadata_id"], :name => "index_ontap_system_derived_metrics_on_smm_id"

    create_table "ontap_system_metrics_rollups" do |t|
      t.datetime "statistic_time"
      t.string   "rollup_type"
      t.bigint   "interval"
      t.float    "cpu_busy"
      t.float    "cpu_busy_min"
      t.float    "cpu_busy_max"
      t.float    "avg_processor_busy"
      t.float    "avg_processor_busy_min"
      t.float    "avg_processor_busy_max"
      t.float    "total_processor_busy"
      t.float    "total_processor_busy_min"
      t.float    "total_processor_busy_max"
      t.float    "read_ops"
      t.float    "read_ops_min"
      t.float    "read_ops_max"
      t.float    "write_ops"
      t.float    "write_ops_min"
      t.float    "write_ops_max"
      t.float    "total_ops"
      t.float    "total_ops_min"
      t.float    "total_ops_max"
      t.float    "sys_read_latency"
      t.float    "sys_read_latency_min"
      t.float    "sys_read_latency_max"
      t.float    "sys_write_latency"
      t.float    "sys_write_latency_min"
      t.float    "sys_write_latency_max"
      t.float    "sys_avg_latency"
      t.float    "sys_avg_latency_min"
      t.float    "sys_avg_latency_max"
      t.float    "nfs_ops"
      t.float    "nfs_ops_min"
      t.float    "nfs_ops_max"
      t.float    "cifs_ops"
      t.float    "cifs_ops_min"
      t.float    "cifs_ops_max"
      t.float    "http_ops"
      t.float    "http_ops_min"
      t.float    "http_ops_max"
      t.float    "fcp_ops"
      t.float    "fcp_ops_min"
      t.float    "fcp_ops_max"
      t.float    "iscsi_ops"
      t.float    "iscsi_ops_min"
      t.float    "iscsi_ops_max"
      t.float    "net_data_recv"
      t.float    "net_data_recv_min"
      t.float    "net_data_recv_max"
      t.float    "net_data_sent"
      t.float    "net_data_sent_min"
      t.float    "net_data_sent_max"
      t.float    "disk_data_read"
      t.float    "disk_data_read_min"
      t.float    "disk_data_read_max"
      t.float    "disk_data_written"
      t.float    "disk_data_written_min"
      t.float    "disk_data_written_max"
      t.text     "base_counters"
      t.bigint   "miq_storage_metric_id"
      t.bigint   "time_profile_id"
      t.datetime "created_at",                               :null => false
      t.datetime "updated_at",                               :null => false
      t.bigint   "miq_cim_instance_id"
      t.bigint   "storage_metrics_metadata_id"
    end

    add_index "ontap_system_metrics_rollups", ["miq_cim_instance_id"], :name => "index_ontap_system_metrics_rollups_on_miq_cim_instance_id"
    add_index "ontap_system_metrics_rollups", ["miq_storage_metric_id"], :name => "index_ontap_system_metrics_rollups_on_miq_storage_metric_id"
    add_index "ontap_system_metrics_rollups", ["storage_metrics_metadata_id"], :name => "index_ontap_system_metrics_rollups_on_smm_id"
    add_index "ontap_system_metrics_rollups", ["time_profile_id"], :name => "index_ontap_system_metrics_rollups_on_time_profile_id"

    create_table "ontap_volume_derived_metrics" do |t|
      t.datetime "statistic_time"
      t.integer  "interval"
      t.float    "avg_latency"
      t.float    "total_ops"
      t.float    "read_data"
      t.float    "read_latency"
      t.float    "read_ops"
      t.float    "write_data"
      t.float    "write_latency"
      t.float    "write_ops"
      t.float    "other_latency"
      t.float    "other_ops"
      t.float    "nfs_read_data"
      t.float    "nfs_read_latency"
      t.float    "nfs_read_ops"
      t.float    "nfs_write_data"
      t.float    "nfs_write_latency"
      t.float    "nfs_write_ops"
      t.float    "nfs_other_latency"
      t.float    "nfs_other_ops"
      t.float    "cifs_read_data"
      t.float    "cifs_read_latency"
      t.float    "cifs_read_ops"
      t.float    "cifs_write_data"
      t.float    "cifs_write_latency"
      t.float    "cifs_write_ops"
      t.float    "cifs_other_latency"
      t.float    "cifs_other_ops"
      t.float    "san_read_data"
      t.float    "san_read_latency"
      t.float    "san_read_ops"
      t.float    "san_write_data"
      t.float    "san_write_latency"
      t.float    "san_write_ops"
      t.float    "san_other_latency"
      t.float    "san_other_ops"
      t.float    "queue_depth"
      t.bigint   "miq_storage_metric_id"
      t.datetime "created_at",                               :null => false
      t.datetime "updated_at",                               :null => false
      t.text     "base_counters"
      t.bigint   "miq_cim_instance_id"
      t.bigint   "storage_metrics_metadata_id"
    end

    add_index "ontap_volume_derived_metrics", ["miq_cim_instance_id"], :name => "index_ontap_volume_derived_metrics_on_miq_cim_instance_id"
    add_index "ontap_volume_derived_metrics", ["miq_storage_metric_id"], :name => "index_ontap_volume_derived_metrics_on_miq_storage_metric_id"
    add_index "ontap_volume_derived_metrics", ["storage_metrics_metadata_id"], :name => "index_ontap_volume_derived_metrics_on_smm_id"

    create_table "ontap_volume_metrics_rollups" do |t|
      t.datetime "statistic_time"
      t.string   "rollup_type"
      t.bigint   "interval"
      t.float    "avg_latency"
      t.float    "avg_latency_min"
      t.float    "avg_latency_max"
      t.float    "total_ops"
      t.float    "total_ops_min"
      t.float    "total_ops_max"
      t.float    "read_data"
      t.float    "read_data_min"
      t.float    "read_data_max"
      t.float    "read_latency"
      t.float    "read_latency_min"
      t.float    "read_latency_max"
      t.float    "read_ops"
      t.float    "read_ops_min"
      t.float    "read_ops_max"
      t.float    "write_data"
      t.float    "write_data_min"
      t.float    "write_data_max"
      t.float    "write_latency"
      t.float    "write_latency_min"
      t.float    "write_latency_max"
      t.float    "write_ops"
      t.float    "write_ops_min"
      t.float    "write_ops_max"
      t.float    "other_latency"
      t.float    "other_latency_min"
      t.float    "other_latency_max"
      t.float    "other_ops"
      t.float    "other_ops_min"
      t.float    "other_ops_max"
      t.float    "nfs_read_data"
      t.float    "nfs_read_data_min"
      t.float    "nfs_read_data_max"
      t.float    "nfs_read_latency"
      t.float    "nfs_read_latency_min"
      t.float    "nfs_read_latency_max"
      t.float    "nfs_read_ops"
      t.float    "nfs_read_ops_min"
      t.float    "nfs_read_ops_max"
      t.float    "nfs_write_data"
      t.float    "nfs_write_data_min"
      t.float    "nfs_write_data_max"
      t.float    "nfs_write_latency"
      t.float    "nfs_write_latency_min"
      t.float    "nfs_write_latency_max"
      t.float    "nfs_write_ops"
      t.float    "nfs_write_ops_min"
      t.float    "nfs_write_ops_max"
      t.float    "nfs_other_latency"
      t.float    "nfs_other_latency_min"
      t.float    "nfs_other_latency_max"
      t.float    "nfs_other_ops"
      t.float    "nfs_other_ops_min"
      t.float    "nfs_other_ops_max"
      t.float    "cifs_read_data"
      t.float    "cifs_read_data_min"
      t.float    "cifs_read_data_max"
      t.float    "cifs_read_latency"
      t.float    "cifs_read_latency_min"
      t.float    "cifs_read_latency_max"
      t.float    "cifs_read_ops"
      t.float    "cifs_read_ops_min"
      t.float    "cifs_read_ops_max"
      t.float    "cifs_write_data"
      t.float    "cifs_write_data_min"
      t.float    "cifs_write_data_max"
      t.float    "cifs_write_latency"
      t.float    "cifs_write_latency_min"
      t.float    "cifs_write_latency_max"
      t.float    "cifs_write_ops"
      t.float    "cifs_write_ops_min"
      t.float    "cifs_write_ops_max"
      t.float    "cifs_other_latency"
      t.float    "cifs_other_latency_min"
      t.float    "cifs_other_latency_max"
      t.float    "cifs_other_ops"
      t.float    "cifs_other_ops_min"
      t.float    "cifs_other_ops_max"
      t.float    "san_read_data"
      t.float    "san_read_data_min"
      t.float    "san_read_data_max"
      t.float    "san_read_latency"
      t.float    "san_read_latency_min"
      t.float    "san_read_latency_max"
      t.float    "san_read_ops"
      t.float    "san_read_ops_min"
      t.float    "san_read_ops_max"
      t.float    "san_write_data"
      t.float    "san_write_data_min"
      t.float    "san_write_data_max"
      t.float    "san_write_latency"
      t.float    "san_write_latency_min"
      t.float    "san_write_latency_max"
      t.float    "san_write_ops"
      t.float    "san_write_ops_min"
      t.float    "san_write_ops_max"
      t.float    "san_other_latency"
      t.float    "san_other_latency_min"
      t.float    "san_other_latency_max"
      t.float    "san_other_ops"
      t.float    "san_other_ops_min"
      t.float    "san_other_ops_max"
      t.text     "base_counters"
      t.bigint   "miq_storage_metric_id"
      t.bigint   "time_profile_id"
      t.datetime "created_at",                               :null => false
      t.datetime "updated_at",                               :null => false
      t.bigint   "miq_cim_instance_id"
      t.bigint   "storage_metrics_metadata_id"
    end

    add_index "ontap_volume_metrics_rollups", ["miq_cim_instance_id"], :name => "index_ontap_volume_metrics_rollups_on_miq_cim_instance_id"
    add_index "ontap_volume_metrics_rollups", ["miq_storage_metric_id"], :name => "index_ontap_volume_metrics_rollups_on_miq_storage_metric_id"
    add_index "ontap_volume_metrics_rollups", ["storage_metrics_metadata_id"], :name => "index_ontap_volume_metrics_rollups_on_smm_id"
    add_index "ontap_volume_metrics_rollups", ["time_profile_id"], :name => "index_ontap_volume_metrics_rollups_on_time_profile_id"

    create_table "operating_systems" do |t|
      t.string  "name"
      t.string  "product_name"
      t.string  "version"
      t.string  "build_number"
      t.string  "system_root"
      t.string  "distribution"
      t.string  "product_type"
      t.string  "service_pack"
      t.string  "productid"
      t.bigint  "vm_or_template_id"
      t.bigint  "host_id"
      t.integer "bitness"
      t.string  "product_key"
      t.integer "pw_hist"
      t.integer "max_pw_age"
      t.integer "min_pw_age"
      t.integer "min_pw_len"
      t.boolean "pw_complex"
      t.boolean "pw_encrypt"
      t.integer "lockout_threshold"
      t.bigint  "lockout_duration"
      t.integer "reset_lockout_counter"
      t.string  "system_type"
    end

    add_index "operating_systems", ["host_id"], :name => "index_operating_systems_on_host_id"
    add_index "operating_systems", ["vm_or_template_id"], :name => "index_operating_systems_on_vm_id"

    create_table "os_processes" do |t|
      t.string   "name"
      t.integer  "pid"
      t.bigint   "memory_usage"
      t.bigint   "memory_size"
      t.float    "percent_memory"
      t.float    "percent_cpu"
      t.integer  "cpu_time"
      t.integer  "priority"
      t.bigint   "operating_system_id"
      t.datetime "created_on"
      t.datetime "updated_on"
    end

    add_index "os_processes", ["operating_system_id"], :name => "index_os_processes_on_operating_system_id"

    create_table "partitions" do |t|
      t.bigint   "disk_id"
      t.string   "name"
      t.bigint   "size"
      t.bigint   "free_space"
      t.bigint   "used_space"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.integer  "location"
      t.bigint   "hardware_id"
      t.string   "volume_group"
      t.integer  "partition_type"
      t.string   "controller"
      t.string   "virtual_disk_file"
      t.string   "uid"
      t.bigint   "start_address"
    end

    add_index "partitions", ["disk_id"], :name => "index_partitions_on_disk_id"
    add_index "partitions", ["hardware_id", "volume_group"], :name => "index_partitions_on_hardware_id_and_volume_group"

    create_table "patches" do |t|
      t.string   "name"
      t.string   "vendor"
      t.text     "description"
      t.string   "service_pack"
      t.string   "is_valid"
      t.string   "installed"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.bigint   "vm_or_template_id"
      t.bigint   "host_id"
      t.datetime "installed_on"
    end

    add_index "patches", ["host_id"], :name => "index_patches_on_host_id"
    add_index "patches", ["vm_or_template_id"], :name => "index_patches_on_vm_id"

    create_table "pictures" do |t|
      t.bigint  "resource_id"
      t.string  "resource_type"
    end

    create_table "policy_event_contents" do |t|
      t.bigint  "policy_event_id"
      t.bigint  "resource_id"
      t.string  "resource_type"
      t.string  "resource_description"
    end

    add_index "policy_event_contents", ["policy_event_id"], :name => "index_policy_event_contents_on_policy_event_id"
    add_index "policy_event_contents", ["resource_id", "resource_type"], :name => "index_policy_event_contents_on_resource_id_and_resource_type"

    create_table "policy_events" do |t|
      t.bigint   "miq_event_id"
      t.string   "event_type"
      t.string   "miq_event_description"
      t.bigint   "miq_policy_id"
      t.string   "miq_policy_description"
      t.string   "result"
      t.datetime "timestamp"
      t.bigint   "target_id"
      t.string   "target_class"
      t.string   "target_name"
      t.bigint   "chain_id"
      t.string   "username"
      t.bigint   "host_id"
      t.bigint   "ems_cluster_id"
      t.bigint   "ems_id"
    end

    add_index "policy_events", ["chain_id"], :name => "index_policy_events_on_chain_id"
    add_index "policy_events", ["ems_cluster_id"], :name => "index_policy_events_on_ems_cluster_id"
    add_index "policy_events", ["ems_id"], :name => "index_policy_events_on_ems_id"
    add_index "policy_events", ["host_id"], :name => "index_policy_events_on_host_id"
    add_index "policy_events", ["miq_event_id"], :name => "index_policy_events_on_miq_event_id"
    add_index "policy_events", ["miq_policy_id"], :name => "index_policy_events_on_miq_policy_id"
    add_index "policy_events", ["target_id", "target_class"], :name => "index_policy_events_on_target_id_and_target_class"

    create_table "product_updates" do |t|
      t.string   "name"
      t.string   "description"
      t.string   "md5"
      t.string   "version"
      t.string   "build"
      t.string   "component"
      t.string   "platform"
      t.string   "arch"
      t.string   "update_type"
      t.string   "vmdb_schema_version"
      t.datetime "created_on"
      t.datetime "updated_on"
    end

    create_table "proxy_tasks" do |t|
      t.integer  "priority"
      t.text     "command"
      t.string   "state"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.bigint   "miq_proxy_id"
    end

    add_index "proxy_tasks", ["miq_proxy_id"], :name => "index_proxy_tasks_on_miq_proxy_id"

    create_table "pxe_image_types" do |t|
      t.string "name"
      t.string "provision_type"
    end

    create_table "pxe_images" do |t|
      t.string   "name"
      t.string   "description"
      t.bigint   "pxe_server_id"
      t.datetime "created_at",                          :null => false
      t.datetime "updated_at",                          :null => false
      t.bigint   "pxe_menu_id"
      t.string   "type"
      t.bigint   "pxe_image_type_id"
      t.string   "kernel",              :limit => 1024
      t.string   "kernel_options",      :limit => 1024
      t.string   "initrd",              :limit => 1024
      t.boolean  "default_for_windows"
      t.string   "path"
    end

    add_index "pxe_images", ["pxe_server_id"], :name => "index_pxe_images_on_pxe_server_id"

    create_table "pxe_menus" do |t|
      t.string   "file_name"
      t.text     "contents"
      t.bigint   "pxe_server_id"
      t.datetime "created_at",                 :null => false
      t.datetime "updated_at",                 :null => false
      t.string   "type"
    end

    create_table "pxe_servers" do |t|
      t.string   "name"
      t.string   "uri_prefix"
      t.string   "uri"
      t.datetime "created_at",               :null => false
      t.datetime "updated_at",               :null => false
      t.datetime "last_refresh_on"
      t.text     "visibility"
      t.string   "access_url"
      t.string   "pxe_directory"
      t.string   "customization_directory"
      t.string   "windows_images_directory"
    end

    create_table "registry_items" do |t|
      t.bigint   "miq_set_id"
      t.bigint   "scan_item_id"
      t.bigint   "vm_or_template_id"
      t.string   "name"
      t.text     "data"
      t.string   "format"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "value_name"
    end

    add_index "registry_items", ["miq_set_id"], :name => "index_registry_items_on_miq_set_id"
    add_index "registry_items", ["scan_item_id"], :name => "index_registry_items_on_scan_item_id"
    add_index "registry_items", ["vm_or_template_id"], :name => "index_registry_items_on_vm_id"

    create_table "relationships" do |t|
      t.string   "resource_type"
      t.bigint   "resource_id"
      t.string   "ancestry",      :limit => 2000
      t.string   "relationship"
      t.datetime "created_at",                    :null => false
      t.datetime "updated_at",                    :null => false
    end

    add_index "relationships", ["ancestry"], :name => "index_relationships_on_ancestry"
    add_index "relationships", ["resource_id", "resource_type", "relationship"], :name => "index_relationships_on_resource_and_relationship"

    create_table "repositories" do |t|
      t.string   "name"
      t.string   "relative_path"
      t.bigint   "storage_id"
      t.datetime "created_on"
      t.datetime "updated_on"
    end

    add_index "repositories", ["storage_id"], :name => "index_repositories_on_storage_id"

    create_table "reserves" do |t|
      t.string  "resource_type"
      t.bigint  "resource_id"
      t.text    "reserved"
    end

    add_index "reserves", ["resource_id", "resource_type"], :name => "index_reserves_on_resource_id_and_resource_type"

    create_table "resource_actions" do |t|
      t.string   "action"
      t.bigint   "dialog_id"
      t.bigint   "resource_id"
      t.string   "resource_type"
      t.datetime "created_at",                 :null => false
      t.datetime "updated_at",                 :null => false
      t.string   "ae_namespace"
      t.string   "ae_class"
      t.string   "ae_instance"
      t.string   "ae_message"
      t.text     "ae_attributes"
    end

    create_table "resource_pools" do |t|
      t.string   "name"
      t.bigint   "ems_id"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "uid_ems"
      t.integer  "memory_reserve"
      t.boolean  "memory_reserve_expand"
      t.integer  "memory_limit"
      t.integer  "memory_shares"
      t.string   "memory_shares_level"
      t.integer  "cpu_reserve"
      t.boolean  "cpu_reserve_expand"
      t.integer  "cpu_limit"
      t.integer  "cpu_shares"
      t.string   "cpu_shares_level"
      t.boolean  "is_default"
      t.string   "ems_ref_obj"
      t.boolean  "vapp"
      t.string   "ems_ref"
    end

    add_index "resource_pools", ["ems_id"], :name => "index_resource_pools_on_ems_id"
    add_index "resource_pools", ["uid_ems"], :name => "index_resource_pools_on_uid"

    create_table "rss_feeds" do |t|
      t.string   "name"
      t.text     "title"
      t.text     "link"
      t.text     "description"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.datetime "yml_file_mtime"
    end

    add_index "rss_feeds", ["name"], :name => "index_rss_feeds_on_name"

    create_table "scan_histories" do |t|
      t.bigint   "vm_or_template_id"
      t.string   "status"
      t.text     "message"
      t.datetime "started_on"
      t.datetime "finished_on"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "task_id",           :limit => 36
      t.integer  "status_code"
    end

    add_index "scan_histories", ["vm_or_template_id"], :name => "index_scan_histories_on_vm_id"

    create_table "scan_items" do |t|
      t.string   "name"
      t.string   "description"
      t.string   "guid",         :limit => 36
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "item_type"
      t.text     "definition"
      t.string   "filename"
      t.datetime "file_mtime"
      t.string   "prod_default"
      t.string   "mode"
    end

    add_index "scan_items", ["guid"], :name => "index_scan_items_on_guid", :unique => true
    add_index "scan_items", ["item_type"], :name => "index_scan_items_on_item_type"
    add_index "scan_items", ["name"], :name => "index_scan_items_on_name"

    create_table "security_groups" do |t|
      t.string  "name"
      t.string  "description"
      t.string  "type"
      t.bigint  "ems_id"
      t.string  "ems_ref"
      t.bigint  "cloud_network_id"
    end

    create_table "security_groups_vms", :id => false do |t|
      t.bigint  "security_group_id"
      t.bigint  "vm_id"
    end

    create_table "server_roles" do |t|
      t.string   "name"
      t.string   "description"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "license_required"
      t.integer  "max_concurrent"
      t.boolean  "external_failover"
      t.string   "role_scope"
    end

    create_table "service_resources" do |t|
      t.bigint   "service_template_id"
      t.bigint   "resource_id"
      t.string   "resource_type"
      t.integer  "group_idx"
      t.integer  "scaling_min"
      t.integer  "scaling_max"
      t.string   "start_action"
      t.integer  "start_delay"
      t.string   "stop_action"
      t.integer  "stop_delay"
      t.datetime "created_at",                       :null => false
      t.datetime "updated_at",                       :null => false
      t.string   "name"
      t.bigint   "service_id"
      t.bigint   "source_id"
      t.string   "source_type"
      t.integer  "provision_index"
    end

    create_table "service_template_catalogs" do |t|
      t.string "name"
      t.string "description"
    end

    create_table "service_templates" do |t|
      t.string   "name"
      t.string   "description"
      t.string   "guid"
      t.string   "type"
      t.bigint   "service_template_id"
      t.text     "options"
      t.datetime "created_at",                               :null => false
      t.datetime "updated_at",                               :null => false
      t.boolean  "display"
      t.bigint   "evm_owner_id"
      t.bigint   "miq_group_id"
      t.string   "service_type"
      t.string   "prov_type"
      t.float    "provision_cost"
      t.bigint   "service_template_catalog_id"
      t.text     "long_description"
    end

    create_table "services" do |t|
      t.string   "name"
      t.string   "description"
      t.string   "guid"
      t.string   "type"
      t.bigint   "service_template_id"
      t.text     "options"
      t.boolean  "display"
      t.datetime "created_at",                        :null => false
      t.datetime "updated_at",                        :null => false
      t.bigint   "evm_owner_id"
      t.bigint   "miq_group_id"
      t.bigint   "service_id"
      t.boolean  "retired"
      t.date     "retires_on"
      t.bigint   "retirement_warn"
      t.datetime "retirement_last_warn"
      t.string   "retirement_state"
    end

    create_table "sessions" do |t|
      t.string   "session_id"
      t.text     "data"
      t.datetime "updated_at"
    end

    add_index "sessions", ["session_id"], :name => "index_sessions_on_session_id"
    add_index "sessions", ["updated_at"], :name => "index_sessions_on_updated_at"

    create_table "snapshots" do |t|
      t.string   "uid"
      t.string   "parent_uid"
      t.string   "name"
      t.text     "description"
      t.integer  "current"
      t.bigint   "total_size"
      t.string   "filename"
      t.datetime "create_time"
      t.text     "disks"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.bigint   "parent_id"
      t.bigint   "vm_or_template_id"
      t.string   "uid_ems"
      t.string   "ems_ref_obj"
      t.string   "ems_ref"
    end

    add_index "snapshots", ["parent_id"], :name => "index_snapshots_on_parent_id"
    add_index "snapshots", ["parent_uid"], :name => "index_snapshots_on_parent_uid"
    add_index "snapshots", ["uid"], :name => "index_snapshots_on_uid"
    add_index "snapshots", ["vm_or_template_id"], :name => "index_snapshots_on_vm_id"

    create_table "storage_files" do |t|
      t.text     "name"
      t.string   "size"
      t.datetime "mtime"
      t.string   "rsc_type"
      t.text     "base_name"
      t.string   "ext_name"
      t.bigint   "storage_id"
      t.bigint   "vm_or_template_id"
    end

    add_index "storage_files", ["storage_id"], :name => "index_storage_files_on_storage_id"
    add_index "storage_files", ["vm_or_template_id"], :name => "index_storage_files_on_vm_id"

    create_table "storage_managers" do |t|
      t.string   "ipaddress"
      t.string   "agent_type"
      t.integer  "last_update_status"
      t.datetime "created_at",                      :null => false
      t.datetime "updated_at",                      :null => false
      t.bigint   "zone_id"
      t.string   "name"
      t.string   "hostname"
      t.string   "port"
      t.bigint   "parent_agent_id"
      t.string   "vendor"
      t.string   "version"
      t.string   "type"
      t.text     "type_spec_data"
    end

    add_index "storage_managers", ["parent_agent_id"], :name => "index_storage_managers_on_parent_agent_id"
    add_index "storage_managers", ["zone_id"], :name => "index_storage_managers_on_zone_id"

    create_table "storage_metrics_metadata" do |t|
      t.string   "type"
      t.text     "counter_info"
      t.datetime "created_at",   :null => false
      t.datetime "updated_at",   :null => false
    end

    create_table "storages" do |t|
      t.string   "name"
      t.string   "store_type"
      t.bigint   "total_space"
      t.bigint   "free_space"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.integer  "multiplehostaccess"
      t.string   "location",                                   :default => ""
      t.datetime "last_scan_on"
      t.bigint   "uncommitted"
      t.datetime "last_perf_capture_on"
      t.string   "ems_ref_obj"
      t.boolean  "directory_hierarchy_supported"
      t.boolean  "thin_provisioning_supported"
      t.boolean  "raw_disk_mappings_supported"
      t.boolean  "master",                                     :default => false
      t.string   "ems_ref"
      t.string   "storage_domain_type"
    end

    add_index "storages", ["location"], :name => "index_storages_on_location"
    add_index "storages", ["name"], :name => "index_storages_on_name"

    create_table "storages_vms_and_templates", :id => false do |t|
      t.bigint  "storage_id"
      t.bigint  "vm_or_template_id"
    end

    add_index "storages_vms_and_templates", ["vm_or_template_id", "storage_id"], :name => "index_storages_vms_on_vm_id_and_storage_id", :unique => true

    create_table "switches" do |t|
      t.bigint   "host_id"
      t.string   "name"
      t.integer  "ports"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "uid_ems"
      t.boolean  "allow_promiscuous"
      t.boolean  "forged_transmits"
      t.boolean  "mac_changes"
    end

    add_index "switches", ["host_id"], :name => "index_switches_on_host_id"
    add_index "switches", ["name"], :name => "index_switches_on_name"

    create_table "system_services" do |t|
      t.string  "name"
      t.string  "svc_type"
      t.string  "typename"
      t.string  "start"
      t.text    "image_path"
      t.string  "display_name"
      t.string  "depend_on_service"
      t.string  "depend_on_group"
      t.string  "object_name"
      t.text    "description"
      t.bigint  "vm_or_template_id"
      t.string  "enable_run_levels"
      t.string  "disable_run_levels"
      t.bigint  "host_id"
      t.boolean "running"
    end

    add_index "system_services", ["host_id"], :name => "index_system_services_on_host_id"
    add_index "system_services", ["typename"], :name => "index_system_services_on_typename"
    add_index "system_services", ["vm_or_template_id"], :name => "index_system_services_on_vm_id"

    create_table "taggings" do |t|
      t.bigint  "taggable_id"
      t.bigint  "tag_id"
      t.string  "taggable_type"
    end

    add_index "taggings", ["tag_id"], :name => "index_taggings_on_tag_id"
    add_index "taggings", ["taggable_id", "taggable_type"], :name => "index_taggings_on_taggable_id_and_taggable_type"

    create_table "tags" do |t|
      t.text "name"
    end

    create_table "time_profiles" do |t|
      t.string   "description"
      t.string   "profile_type"
      t.string   "profile_key"
      t.text     "profile"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.boolean  "rollup_daily_metrics"
    end

    create_table "ui_tasks" do |t|
      t.string   "name"
      t.string   "area"
      t.string   "typ"
      t.string   "task"
      t.datetime "created_on"
      t.datetime "updated_on"
    end

    add_index "ui_tasks", ["area", "typ", "task"], :name => "index_ui_tasks_on_area_and_typ_and_task"

    create_table "users" do |t|
      t.string   "name"
      t.string   "email"
      t.string   "icon"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "userid"
      t.text     "settings"
      t.text     "filters"
      t.bigint   "ui_task_set_id"
      t.datetime "lastlogon"
      t.datetime "lastlogoff"
      t.integer  "region"
      t.bigint   "miq_group_id"
      t.string   "first_name"
      t.string   "last_name"
      t.string   "password_digest"
    end

    add_index "users", ["miq_group_id"], :name => "index_users_on_miq_group_id"
    add_index "users", ["ui_task_set_id"], :name => "index_users_on_ui_task_set_id"
    add_index "users", ["userid", "region"], :name => "index_users_on_userid_and_region", :unique => true

    create_table "vdi_controllers" do |t|
      t.bigint   "vdi_farm_id"
      t.string   "name"
      t.string   "version"
      t.string   "zone_preference"
      t.datetime "created_at",                   :null => false
      t.datetime "updated_at",                   :null => false
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
      t.datetime "created_at",                            :null => false
      t.datetime "updated_at",                            :null => false
    end

    add_index "vdi_desktop_pools", ["vdi_farm_id"], :name => "index_vdi_desktop_pools_on_vdi_farm_id"

    create_table "vdi_desktop_pools_vdi_users", :id => false do |t|
      t.bigint  "vdi_desktop_pool_id"
      t.bigint  "vdi_user_id"
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
      t.datetime "created_at",                       :null => false
      t.datetime "updated_at",                       :null => false
    end

    add_index "vdi_desktops", ["vdi_desktop_pool_id"], :name => "index_vdi_desktops_on_vdi_desktop_pool_id"
    add_index "vdi_desktops", ["vm_or_template_id"], :name => "index_vdi_desktops_on_vm_id"

    create_table "vdi_desktops_vdi_users", :id => false do |t|
      t.bigint  "vdi_desktop_id"
      t.bigint  "vdi_user_id"
    end

    create_table "vdi_endpoint_devices" do |t|
      t.string   "name"
      t.string   "ipaddress"
      t.string   "uid_ems"
      t.datetime "created_at", :null => false
      t.datetime "updated_at", :null => false
    end

    create_table "vdi_farms" do |t|
      t.string   "name"
      t.string   "vendor"
      t.string   "edition"
      t.string   "uid_ems"
      t.string   "license_server_name"
      t.string   "enable_session_reliability"
      t.datetime "created_at",                              :null => false
      t.datetime "updated_at",                              :null => false
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
      t.datetime "created_at",                          :null => false
      t.datetime "updated_at",                          :null => false
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
      t.datetime "created_at", :null => false
      t.datetime "updated_at", :null => false
    end

    create_table "vim_performance_operating_ranges" do |t|
      t.bigint   "resource_id"
      t.string   "resource_type"
      t.bigint   "time_profile_id"
      t.datetime "created_at",                   :null => false
      t.datetime "updated_at",                   :null => false
      t.text     "values"
      t.integer  "days"
    end

    add_index "vim_performance_operating_ranges", ["resource_id", "resource_type"], :name => "index_vpor_on_resource"
    add_index "vim_performance_operating_ranges", ["time_profile_id"], :name => "index_vpor_on_time_profile_id"

    create_table "vim_performance_states" do |t|
      t.datetime "timestamp"
      t.integer  "capture_interval"
      t.string   "resource_type"
      t.bigint   "resource_id"
      t.text     "state_data"
    end

    add_index "vim_performance_states", ["resource_id", "resource_type", "timestamp"], :name => "index_vim_performance_states_on_resource_and_timestamp"

    create_table "vim_performance_tag_values" do |t|
      t.string  "association_type"
      t.string  "category"
      t.string  "tag_name"
      t.string  "column_name"
      t.float   "value"
      t.text    "assoc_ids"
      t.bigint  "metric_id"
      t.string  "metric_type"
    end

    add_index "vim_performance_tag_values", ["metric_id", "metric_type"], :name => "index_vim_performance_tag_values_on_metric_id_and_metric_type"

    create_table "vmdb_database_metrics" do |t|
      t.bigint   "vmdb_database_id"
      t.integer  "running_processes"
      t.integer  "active_connections"
      t.datetime "timestamp"
      t.string   "capture_interval_name"
      t.bigint   "disk_total_bytes"
      t.bigint   "disk_free_bytes"
      t.bigint   "disk_used_bytes"
      t.bigint   "disk_total_inodes"
      t.bigint   "disk_used_inodes"
      t.bigint   "disk_free_inodes"
    end

    create_table "vmdb_databases" do |t|
      t.string   "name"
      t.string   "ipaddress"
      t.string   "vendor"
      t.string   "version"
      t.string   "data_directory"
      t.datetime "last_start_time"
      t.string   "data_disk"
    end

    create_table "vmdb_indexes" do |t|
      t.bigint  "vmdb_table_id"
      t.string  "name"
      t.text    "prior_raw_metrics"
    end

    create_table "vmdb_metrics" do |t|
      t.bigint   "resource_id"
      t.string   "resource_type"
      t.bigint   "size"
      t.bigint   "rows"
      t.bigint   "pages"
      t.float    "percent_bloat"
      t.float    "wasted_bytes"
      t.integer  "otta"
      t.bigint   "table_scans"
      t.bigint   "sequential_rows_read"
      t.bigint   "index_scans"
      t.bigint   "index_rows_fetched"
      t.bigint   "rows_inserted"
      t.bigint   "rows_updated"
      t.bigint   "rows_deleted"
      t.bigint   "rows_hot_updated"
      t.bigint   "rows_live"
      t.bigint   "rows_dead"
      t.datetime "last_vacuum_date"
      t.datetime "last_autovacuum_date"
      t.datetime "last_analyze_date"
      t.datetime "last_autoanalyze_date"
      t.datetime "timestamp"
      t.string   "capture_interval_name"
    end

    add_index "vmdb_metrics", ["resource_id", "resource_type", "timestamp"], :name => "index_vmdb_metrics_on_resource_and_timestamp"

    create_table "vmdb_tables" do |t|
      t.bigint  "vmdb_database_id"
      t.string  "name"
      t.string  "type"
      t.bigint  "parent_id"
      t.text    "prior_raw_metrics"
    end

    create_table "vms" do |t|
      t.string   "vendor"
      t.string   "format"
      t.string   "version"
      t.string   "name"
      t.text     "description"
      t.string   "location"
      t.string   "config_xml"
      t.string   "autostart"
      t.bigint   "host_id"
      t.datetime "last_sync_on"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.bigint   "storage_id"
      t.string   "guid",                  :limit => 36
      t.bigint   "ems_id"
      t.datetime "last_scan_on"
      t.datetime "last_scan_attempt_on"
      t.string   "uid_ems"
      t.date     "retires_on"
      t.boolean  "retired"
      t.datetime "boot_time"
      t.string   "tools_status"
      t.string   "standby_action"
      t.string   "power_state"
      t.datetime "state_changed_on"
      t.string   "previous_state"
      t.string   "connection_state"
      t.datetime "last_perf_capture_on"
      t.boolean  "blackbox_exists"
      t.boolean  "blackbox_validated"
      t.boolean  "registered"
      t.boolean  "busy"
      t.boolean  "smart"
      t.integer  "memory_reserve"
      t.boolean  "memory_reserve_expand"
      t.integer  "memory_limit"
      t.integer  "memory_shares"
      t.string   "memory_shares_level"
      t.integer  "cpu_reserve"
      t.boolean  "cpu_reserve_expand"
      t.integer  "cpu_limit"
      t.integer  "cpu_shares"
      t.string   "cpu_shares_level"
      t.string   "cpu_affinity"
      t.datetime "ems_created_on"
      t.boolean  "template",                            :default => false
      t.bigint   "evm_owner_id"
      t.string   "ems_ref_obj"
      t.bigint   "miq_group_id"
      t.boolean  "vdi",                                 :default => false, :null => false
      t.boolean  "linked_clone"
      t.boolean  "fault_tolerance"
      t.string   "type"
      t.string   "ems_ref"
      t.bigint   "ems_cluster_id"
      t.bigint   "retirement_warn"
      t.datetime "retirement_last_warn"
      t.integer  "vnc_port"
      t.bigint   "flavor_id"
      t.bigint   "availability_zone_id"
      t.boolean  "cloud"
      t.string   "retirement_state"
      t.bigint   "cloud_network_id"
      t.bigint   "cloud_subnet_id"
    end

    add_index "vms", ["availability_zone_id"], :name => "index_vms_on_availability_zone_id"
    add_index "vms", ["ems_id"], :name => "index_vms_on_ems_id"
    add_index "vms", ["evm_owner_id"], :name => "index_vms_on_evm_owner_id"
    add_index "vms", ["flavor_id"], :name => "index_vms_on_flavor_id"
    add_index "vms", ["guid"], :name => "index_vms_on_guid", :unique => true
    add_index "vms", ["host_id"], :name => "index_vms_on_host_id"
    add_index "vms", ["location"], :name => "index_vms_on_location"
    add_index "vms", ["miq_group_id"], :name => "index_vms_on_miq_group_id"
    add_index "vms", ["name"], :name => "index_vms_on_name"
    add_index "vms", ["storage_id"], :name => "index_vms_on_storage_id"
    add_index "vms", ["uid_ems"], :name => "index_vms_on_vmm_uuid"

    create_table "volumes" do |t|
      t.string   "name"
      t.string   "typ"
      t.string   "filesystem"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.bigint   "hardware_id"
      t.string   "volume_group"
      t.string   "uid"
      t.bigint   "size"
      t.bigint   "free_space"
      t.bigint   "used_space"
    end

    add_index "volumes", ["hardware_id", "volume_group"], :name => "index_volumes_on_hardware_id_and_volume_group"

    create_table "windows_images" do |t|
      t.string  "name"
      t.string  "description"
      t.string  "path"
      t.integer "index"
      t.bigint  "pxe_server_id"
      t.bigint  "pxe_image_type_id"
    end

    create_table "zones" do |t|
      t.string   "name"
      t.string   "description"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "settings"
    end
  end

  def down
    drop_table "zones"
    drop_table "windows_images"
    drop_table "volumes"
    drop_table "vms"
    drop_table "vmdb_tables"
    drop_table "vmdb_metrics"
    drop_table "vmdb_indexes"
    drop_table "vmdb_databases"
    drop_table "vmdb_database_metrics"
    drop_table "vim_performance_tag_values"
    drop_table "vim_performance_states"
    drop_table "vim_performance_operating_ranges"
    drop_table "vdi_users"
    drop_table "vdi_sessions"
    drop_table "vdi_farms"
    drop_table "vdi_endpoint_devices"
    drop_table "vdi_desktops_vdi_users"
    drop_table "vdi_desktops"
    drop_table "vdi_desktop_pools_vdi_users"
    drop_table "vdi_desktop_pools"
    drop_table "vdi_controllers"
    drop_table "users"
    drop_table "ui_tasks"
    drop_table "time_profiles"
    drop_table "tags"
    drop_table "taggings"
    drop_table "system_services"
    drop_table "switches"
    drop_table "storages_vms_and_templates"
    drop_table "storages"
    drop_table "storage_metrics_metadata"
    drop_table "storage_managers"
    drop_table "storage_files"
    drop_table "snapshots"
    drop_table "sessions"
    drop_table "services"
    drop_table "service_templates"
    drop_table "service_template_catalogs"
    drop_table "service_resources"
    drop_table "server_roles"
    drop_table "security_groups_vms"
    drop_table "security_groups"
    drop_table "scan_items"
    drop_table "scan_histories"
    drop_table "rss_feeds"
    drop_table "resource_pools"
    drop_table "resource_actions"
    drop_table "reserves"
    drop_table "repositories"
    drop_table "relationships"
    drop_table "registry_items"
    drop_table "pxe_servers"
    drop_table "pxe_menus"
    drop_table "pxe_images"
    drop_table "pxe_image_types"
    drop_table "proxy_tasks"
    drop_table "product_updates"
    drop_table "policy_events"
    drop_table "policy_event_contents"
    drop_table "pictures"
    drop_table "patches"
    drop_table "partitions"
    drop_table "os_processes"
    drop_table "operating_systems"
    drop_table "ontap_volume_metrics_rollups"
    drop_table "ontap_volume_derived_metrics"
    drop_table "ontap_system_metrics_rollups"
    drop_table "ontap_system_derived_metrics"
    drop_table "ontap_lun_metrics_rollups"
    drop_table "ontap_lun_derived_metrics"
    drop_table "ontap_disk_metrics_rollups"
    drop_table "ontap_disk_derived_metrics"
    drop_table "ontap_aggregate_metrics_rollups"
    drop_table "ontap_aggregate_derived_metrics"
    drop_table "networks"
    drop_table "miq_workers"
    drop_table "miq_widgets"
    drop_table "miq_widget_shortcuts"
    drop_table "miq_widget_contents"
    drop_table "miq_user_roles"
    drop_table "miq_tasks"
    drop_table "miq_storage_metrics"
    drop_table "miq_shortcuts"
    drop_table "miq_sets"
    drop_table "miq_servers_product_updates"
    drop_table "miq_servers"
    drop_table "miq_searches"
    drop_table "miq_scsi_targets"
    drop_table "miq_scsi_luns"
    drop_table "miq_schedules"
    drop_table "miq_roles_features"
    drop_table "miq_requests"
    drop_table "miq_request_tasks"
    drop_table "miq_reports"
    drop_table "miq_report_results"
    drop_table "miq_report_result_details"
    drop_table "miq_regions"
    drop_table "miq_queue"
    drop_table "miq_proxies_product_updates"
    drop_table "miq_proxies"
    drop_table "miq_product_features"
    drop_table "miq_policy_contents"
    drop_table "miq_policies"
    drop_table "miq_license_contents"
    drop_table "miq_groups"
    drop_table "miq_globals"
    drop_table "miq_events"
    drop_table "miq_enterprises"
    drop_table "miq_dialogs"
    drop_table "miq_databases"
    drop_table "miq_cim_instances"
    drop_table "miq_cim_derived_metrics"
    drop_table "miq_cim_associations"
    drop_table "miq_approvals"
    drop_table "miq_alerts"
    drop_table "miq_alert_statuses"
    drop_table "miq_ae_workspaces"
    drop_table "miq_ae_values"
    drop_table "miq_ae_namespaces"
    drop_table "miq_ae_methods"
    drop_table "miq_ae_instances"
    drop_table "miq_ae_fields"
    drop_table "miq_ae_classes"
    drop_table "miq_actions"

    drop_inheritance_triggers "metrics"
    (0..23).each { |n| drop_table subtable_name("metrics", n) }
    drop_table "metrics"

    drop_inheritance_triggers "metric_rollups"
    (1..12).each { |n| drop_table subtable_name("metric_rollups", n) }
    drop_table "metric_rollups"

    drop_table "log_files"
    drop_table "lifecycle_events"
    drop_table "ldap_users"
    drop_table "ldap_servers"
    drop_table "ldap_regions"
    drop_table "ldap_managements"
    drop_table "ldap_groups"
    drop_table "ldap_domains"
    drop_table "lans"
    drop_table "key_pairs_vms"
    drop_table "jobs"
    drop_table "iso_images"
    drop_table "iso_datastores"
    drop_table "hosts_storages"
    drop_table "hosts"
    drop_table "hardwares"
    drop_table "guest_devices"
    drop_table "guest_applications"
    drop_table "floating_ips"
    drop_table "flavors"
    drop_table "firewall_rules"
    drop_table "filesystems"
    drop_table "file_depots"
    drop_table "ext_management_systems_vdi_desktop_pools"
    drop_table "ext_management_systems"
    drop_table "event_logs"
    drop_table "ems_folders"
    drop_table "ems_events"
    drop_table "ems_clusters"
    drop_table "drift_states"
    drop_table "disks"
    drop_table "dialogs"
    drop_table "dialog_tabs"
    drop_table "dialog_groups"
    drop_table "dialog_fields"
    drop_table "database_backups"
    drop_table "customization_templates"
    drop_table "customization_specs"
    drop_table "custom_buttons"
    drop_table "custom_attributes"
    drop_table "configurations"
    drop_table "conditions_miq_policies"
    drop_table "conditions"
    drop_table "compliances"
    drop_table "compliance_details"
    drop_table "cloud_volumes"
    drop_table "cloud_volume_snapshots"
    drop_table "cloud_subnets"
    drop_table "cloud_networks"
    drop_table "classifications"
    drop_table "chargeback_rates"
    drop_table "chargeback_rate_details"
    drop_table "bottleneck_events"
    drop_table "binary_blobs"
    drop_table "binary_blob_parts"
    drop_table "availability_zones"
    drop_table "authentications"
    drop_table "audit_events"
    drop_table "assigned_server_roles"
    drop_table "advanced_settings"
    drop_table "accounts"

    say_with_time("Clean old migrations from schema_migrations") do
      connection.truncate("schema_migrations")
    end
  end

  def create_trigger_language
    say_with_time("create_trigger_language") do
      language_name = "plpgsql"

      count = connection.select_value <<-EOSQL, 'Query Language'
        SELECT COUNT(*) FROM pg_language WHERE lanname = '#{language_name}';
      EOSQL

      if count.to_i == 0
        connection.execute <<-EOSQL, 'Create language'
          CREATE LANGUAGE #{language_name};
        EOSQL
      end
    end
  end

  def create_metrics_table(table)
    create_table table do |t|
      t.datetime "timestamp"
      t.integer  "capture_interval"
      t.string   "resource_type"
      t.bigint   "resource_id"
      t.float    "cpu_usage_rate_average"
      t.float    "cpu_usagemhz_rate_average"
      t.float    "mem_usage_absolute_average"
      t.float    "disk_usage_rate_average"
      t.float    "net_usage_rate_average"
      t.float    "sys_uptime_absolute_latest"
      t.datetime "created_on"
      t.float    "derived_cpu_available"
      t.float    "derived_memory_available"
      t.float    "derived_memory_used"
      t.float    "derived_cpu_reserved"
      t.float    "derived_memory_reserved"
      t.integer  "derived_vm_count_on"
      t.integer  "derived_host_count_on"
      t.integer  "derived_vm_count_off"
      t.integer  "derived_host_count_off"
      t.float    "derived_storage_total"
      t.float    "derived_storage_free"
      t.string   "capture_interval_name"
      t.text     "assoc_ids"
      t.float    "cpu_ready_delta_summation"
      t.float    "cpu_system_delta_summation"
      t.float    "cpu_wait_delta_summation"
      t.string   "resource_name"
      t.float    "cpu_used_delta_summation"
      t.text     "tag_names"
      t.bigint   "parent_host_id"
      t.bigint   "parent_ems_cluster_id"
      t.bigint   "parent_storage_id"
      t.bigint   "parent_ems_id"
      t.float    "derived_storage_vm_count_registered"
      t.float    "derived_storage_vm_count_unregistered"
      t.float    "derived_storage_vm_count_unmanaged"
      t.float    "derived_storage_used_registered"
      t.float    "derived_storage_used_unregistered"
      t.float    "derived_storage_used_unmanaged"
      t.float    "derived_storage_snapshot_registered"
      t.float    "derived_storage_snapshot_unregistered"
      t.float    "derived_storage_snapshot_unmanaged"
      t.float    "derived_storage_mem_registered"
      t.float    "derived_storage_mem_unregistered"
      t.float    "derived_storage_mem_unmanaged"
      t.float    "derived_storage_disk_registered"
      t.float    "derived_storage_disk_unregistered"
      t.float    "derived_storage_disk_unmanaged"
      t.float    "derived_storage_vm_count_managed"
      t.float    "derived_storage_used_managed"
      t.float    "derived_storage_snapshot_managed"
      t.float    "derived_storage_mem_managed"
      t.float    "derived_storage_disk_managed"
      t.text     "min_max"
      t.integer  "intervals_in_rollup"
      t.float    "mem_vmmemctl_absolute_average"
      t.float    "mem_vmmemctltarget_absolute_average"
      t.float    "mem_swapin_absolute_average"
      t.float    "mem_swapout_absolute_average"
      t.float    "mem_swapped_absolute_average"
      t.float    "mem_swaptarget_absolute_average"
      t.float    "disk_devicelatency_absolute_average"
      t.float    "disk_kernellatency_absolute_average"
      t.float    "disk_queuelatency_absolute_average"
      t.float    "derived_vm_used_disk_storage"
      t.float    "derived_vm_allocated_disk_storage"
      t.float    "derived_vm_numvcpus"
      t.bigint   "time_profile_id"
    end
  end

  def add_metrics_indexes(table)
    add_index table, ["resource_id", "resource_type", "capture_interval_name", "timestamp"], :name => "index_#{table}_on_resource_and_ts"
    add_index table, ["timestamp", "capture_interval_name", "resource_id", "resource_type"], :name => "index_#{table}_on_ts_and_capture_interval_name"
  end

  def subtable_name(inherit_from, index)
    "#{inherit_from}_#{index.to_s.rjust(2, '0')}"
  end

  # NOTE: The reason we are doing the inheritance with a before that adds and
  # an after trigger that deletes is that otherwise returning NULL from the
  # before trigger causes INSERT INTO RETURNING to return nil.  ActiveRecord
  # uses this insert format to get the resultant id, so it ends up creating
  # an AR instance with a nil instead of an id.
  # See: https://gist.github.com/59067

  def add_metrics_inheritance_triggers
    add_trigger "before", "metrics", "metrics_inheritance_before", <<-EOSQL
      CASE EXTRACT(HOUR FROM NEW.timestamp)
        WHEN 0 THEN
          INSERT INTO metrics_00 VALUES (NEW.*);
        WHEN 1 THEN
          INSERT INTO metrics_01 VALUES (NEW.*);
        WHEN 2 THEN
          INSERT INTO metrics_02 VALUES (NEW.*);
        WHEN 3 THEN
          INSERT INTO metrics_03 VALUES (NEW.*);
        WHEN 4 THEN
          INSERT INTO metrics_04 VALUES (NEW.*);
        WHEN 5 THEN
          INSERT INTO metrics_05 VALUES (NEW.*);
        WHEN 6 THEN
          INSERT INTO metrics_06 VALUES (NEW.*);
        WHEN 7 THEN
          INSERT INTO metrics_07 VALUES (NEW.*);
        WHEN 8 THEN
          INSERT INTO metrics_08 VALUES (NEW.*);
        WHEN 9 THEN
          INSERT INTO metrics_09 VALUES (NEW.*);
        WHEN 10 THEN
          INSERT INTO metrics_10 VALUES (NEW.*);
        WHEN 11 THEN
          INSERT INTO metrics_11 VALUES (NEW.*);
        WHEN 12 THEN
          INSERT INTO metrics_12 VALUES (NEW.*);
        WHEN 13 THEN
          INSERT INTO metrics_13 VALUES (NEW.*);
        WHEN 14 THEN
          INSERT INTO metrics_14 VALUES (NEW.*);
        WHEN 15 THEN
          INSERT INTO metrics_15 VALUES (NEW.*);
        WHEN 16 THEN
          INSERT INTO metrics_16 VALUES (NEW.*);
        WHEN 17 THEN
          INSERT INTO metrics_17 VALUES (NEW.*);
        WHEN 18 THEN
          INSERT INTO metrics_18 VALUES (NEW.*);
        WHEN 19 THEN
          INSERT INTO metrics_19 VALUES (NEW.*);
        WHEN 20 THEN
          INSERT INTO metrics_20 VALUES (NEW.*);
        WHEN 21 THEN
          INSERT INTO metrics_21 VALUES (NEW.*);
        WHEN 22 THEN
          INSERT INTO metrics_22 VALUES (NEW.*);
        WHEN 23 THEN
          INSERT INTO metrics_23 VALUES (NEW.*);
      END CASE;
      RETURN NEW;
    EOSQL

    add_trigger "after", "metrics", "metrics_inheritance_after", <<-EOSQL
      DELETE FROM ONLY metrics WHERE id = NEW.id;
      RETURN NEW;
    EOSQL
  end

  def add_metric_rollups_inheritance_triggers
    add_trigger "before", "metric_rollups", "metric_rollups_inheritance_before", <<-EOSQL
      CASE EXTRACT(MONTH FROM NEW.timestamp)
        WHEN 1 THEN
          INSERT INTO metric_rollups_01 VALUES (NEW.*);
        WHEN 2 THEN
          INSERT INTO metric_rollups_02 VALUES (NEW.*);
        WHEN 3 THEN
          INSERT INTO metric_rollups_03 VALUES (NEW.*);
        WHEN 4 THEN
          INSERT INTO metric_rollups_04 VALUES (NEW.*);
        WHEN 5 THEN
          INSERT INTO metric_rollups_05 VALUES (NEW.*);
        WHEN 6 THEN
          INSERT INTO metric_rollups_06 VALUES (NEW.*);
        WHEN 7 THEN
          INSERT INTO metric_rollups_07 VALUES (NEW.*);
        WHEN 8 THEN
          INSERT INTO metric_rollups_08 VALUES (NEW.*);
        WHEN 9 THEN
          INSERT INTO metric_rollups_09 VALUES (NEW.*);
        WHEN 10 THEN
          INSERT INTO metric_rollups_10 VALUES (NEW.*);
        WHEN 11 THEN
          INSERT INTO metric_rollups_11 VALUES (NEW.*);
        WHEN 12 THEN
          INSERT INTO metric_rollups_12 VALUES (NEW.*);
      END CASE;
      RETURN NEW;
    EOSQL

    add_trigger "after", "metric_rollups", "metric_rollups_inheritance_after", <<-EOSQL
      DELETE FROM ONLY metric_rollups WHERE id = NEW.id;
      RETURN NEW;
    EOSQL
  end

  def drop_inheritance_triggers(table)
    drop_trigger table, "#{table}_inheritance_before"
    drop_trigger table, "#{table}_inheritance_after"
  end

end
