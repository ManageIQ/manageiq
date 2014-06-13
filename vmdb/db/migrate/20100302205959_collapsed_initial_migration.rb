require Rails.root.join('lib/migration_helper')

class CollapsedInitialMigration < ActiveRecord::Migration
  include MigrationHelper
  include MigrationHelper::PerformancesViews

  def up
    create_table "accounts" do |t|
      t.string   "name"
      t.integer  "acctid"
      t.string   "homedir"
      t.boolean  "local"
      t.string   "domain"
      t.string   "accttype"
      t.integer  "vm_id"
      t.string   "display_name"
      t.string   "comment"
      t.string   "expires"
      t.boolean  "enabled"
      t.text     "reserved"
      t.datetime "last_logon"
      t.integer  "host_id"
    end

    add_index "accounts", ["accttype"], :name => "index_accounts_on_accttype"
    add_index "accounts", ["vm_id"], :name => "index_accounts_on_vm_id"

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
      t.integer  "resource_id"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "reserved"
    end

    create_table "assigned_server_roles" do |t|
      t.integer "miq_server_id"
      t.integer "server_role_id"
      t.boolean "active"
      t.text    "reserved"
    end

    create_table "audit_events" do |t|
      t.string   "event"
      t.string   "status"
      t.text     "message"
      t.string   "severity"
      t.integer  "target_id"
      t.string   "target_class"
      t.string   "userid"
      t.string   "source"
      t.datetime "created_on"
      t.text     "reserved"
    end

    create_table "authentications" do |t|
      t.string   "name"
      t.string   "authtype"
      t.string   "userid"
      t.string   "password"
      t.integer  "resource_id"
      t.string   "resource_type"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "reserved"
    end

    add_index "authentications", ["resource_type", "resource_id"], :name => "index_authentications_on_resource_type_and_resource_id"

    create_table "automation_uris" do |t|
      t.string   "guid",              :limit => 36
      t.string   "description"
      t.string   "applies_to_class"
      t.text     "applies_to_exp"
      t.integer  "button_id"
      t.text     "uri"
      t.string   "uri_path"
      t.string   "uri_message"
      t.text     "options"
      t.string   "userid"
      t.boolean  "wait_for_complete"
      t.datetime "created_on"
      t.datetime "updated_on"
    end

    create_table "binary_blob_parts" do |t|
      t.string  "md5"
      t.binary  "data"
      t.text    "reserved"
      t.integer "binary_blob_id"
      t.decimal "size",           :precision => 20, :scale => 0
    end

    add_index "binary_blob_parts", ["binary_blob_id"], :name => "index_binary_blob_parts_on_binary_blob_id"

    create_table "binary_blobs" do |t|
      t.string  "resource_type"
      t.integer "resource_id"
      t.string  "md5"
      t.text    "reserved"
      t.decimal "size",          :precision => 20, :scale => 0
      t.decimal "part_size",     :precision => 20, :scale => 0
      t.string  "name"
      t.string  "data_type"
    end

    add_index "binary_blobs", ["resource_type", "resource_id"], :name => "index_binary_blobs_on_resource_type_and_resource_id"

    create_table "bottleneck_events" do |t|
      t.datetime "timestamp"
      t.datetime "created_on"
      t.string   "resource_name"
      t.string   "resource_type"
      t.integer  "resource_id"
      t.string   "event_type"
      t.integer  "severity"
      t.string   "message"
      t.text     "context_data"
      t.text     "reserved"
      t.boolean  "future"
    end

    create_table "classifications" do |t|
      t.text    "description"
      t.string  "icon"
      t.string  "read_only"
      t.string  "syntax"
      t.string  "single_value"
      t.text    "example_text"
      t.integer "tag_id"
      t.integer "parent_id",    :default => 0
      t.text    "reserved"
      t.boolean "show"
      t.string  "default"
    end

    add_index "classifications", ["parent_id"], :name => "index_classifications_on_parent_id"
    add_index "classifications", ["tag_id"], :name => "index_classifications_on_tag_id"

    create_table "compliance_details" do |t|
      t.integer  "compliance_id"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.integer  "miq_policy_id"
      t.string   "miq_policy_desc"
      t.boolean  "miq_policy_result"
      t.integer  "condition_id"
      t.string   "condition_desc"
      t.boolean  "condition_result"
    end

    create_table "compliances" do |t|
      t.integer  "resource_id"
      t.string   "resource_type"
      t.boolean  "compliant"
      t.text     "reserved"
      t.datetime "timestamp"
      t.datetime "updated_on"
      t.string   "event_type"
    end

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
      t.text     "reserved"
      t.integer  "miq_policy_id"
      t.string   "notes",          :limit => 512
    end

    add_index "conditions", ["guid"], :name => "index_conditions_on_guid", :unique => true

    create_table "conditions_miq_policies", :id => false do |t|
      t.integer "miq_policy_id"
      t.integer "condition_id"
    end

    create_table "configurations" do |t|
      t.integer  "miq_server_id"
      t.string   "typ"
      t.text     "settings"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "reserved"
    end

    create_table "custom_attributes" do |t|
      t.string  "section"
      t.string  "name"
      t.string  "value"
      t.string  "resource_type"
      t.integer "resource_id"
      t.text    "reserved"
    end

    create_table "disks" do |t|
      t.string   "device_name"
      t.string   "device_type"
      t.string   "location"
      t.string   "filename"
      t.integer  "hardware_id"
      t.string   "mode"
      t.string   "controller_type"
      numeric_column_with_db_differences(t, "size")
      numeric_column_with_db_differences(t, "free_space")
      numeric_column_with_db_differences(t, "size_on_disk")
      t.boolean  "present",         :default => true
      t.boolean  "start_connected", :default => true
      t.boolean  "auto_detect"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "reserved"
      t.string   "disk_type"
    end

    add_index "disks", ["device_name"], :name => "index_disks_on_device_name"
    add_index "disks", ["device_type"], :name => "index_disks_on_device_type"
    add_index "disks", ["hardware_id"], :name => "index_disks_on_hardware_id"

    create_table "ems_clusters" do |t|
      t.string   "name"
      t.integer  "ems_id"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "uid_ems"
      t.boolean  "ha_enabled"
      t.boolean  "ha_admit_control"
      t.integer  "ha_max_failures"
      t.boolean  "drs_enabled"
      t.string   "drs_automation_level"
      t.integer  "drs_migration_threshold"
      t.text     "reserved"
      t.datetime "last_perf_capture_on"
    end

    add_index "ems_clusters", ["ems_id"], :name => "index_ems_clusters_on_ems_id"
    add_index "ems_clusters", ["uid_ems"], :name => "index_ems_clusters_on_uid"

    create_table "ems_events" do |t|
      t.string   "event_type"
      t.text     "message"
      t.datetime "timestamp"
      t.string   "host_name"
      t.integer  "host_id"
      t.string   "vm_name"
      t.string   "vm_location"
      t.integer  "vm_id"
      t.string   "dest_host_name"
      t.integer  "dest_host_id"
      t.string   "dest_vm_name"
      t.string   "dest_vm_location"
      t.integer  "dest_vm_id"
      t.string   "source"
      t.integer  "chain_id"
      t.integer  "ems_id"
      t.boolean  "is_task"
      t.text     "full_data"
      t.datetime "created_on"
      t.string   "username"
      t.integer  "ems_cluster_id"
      t.string   "ems_cluster_name"
      t.string   "ems_cluster_uid"
      t.integer  "dest_ems_cluster_id"
      t.string   "dest_ems_cluster_name"
      t.string   "dest_ems_cluster_uid"
      t.text     "reserved"
    end

    add_index "ems_events", ["ems_id", "chain_id"], :name => "index_ems_events_on_ems_id_and_chain_id"
    add_index "ems_events", ["event_type"], :name => "index_ems_events_on_event_type"
    add_index "ems_events", ["timestamp"], :name => "index_ems_events_on_timestamp"

    create_table "ems_folders" do |t|
      t.string   "name"
      t.boolean  "is_datacenter"
      t.integer  "ems_id"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "uid_ems"
      t.text     "reserved"
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
      t.text     "reserved"
      t.integer  "operating_system_id"
      t.string   "level"
      t.string   "category"
    end

    create_table "ext_management_systems" do |t|
      t.string   "name"
      t.string   "emstype"
      t.string   "port"
      t.string   "hostname"
      t.string   "ipaddress"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "guid",       :limit => 36
      t.text     "reserved"
      t.integer  "zone_id"
    end

    add_index "ext_management_systems", ["guid"], :name => "index_ext_management_systems_on_guid", :unique => true

    create_table "filesystems" do |t|
      t.text     "name"
      t.string   "md5"
      numeric_column_with_db_differences(t, "size")
      t.datetime "atime"
      t.datetime "mtime"
      t.datetime "ctime"
      t.string   "rsc_type"
      t.text     "base_name"
      t.integer  "miq_set_id"
      t.integer  "scan_item_id"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "file_version"
      t.string   "product_version"
      t.string   "file_version_header"
      t.string   "product_version_header"
      t.text     "reserved"
      t.string   "resource_type"
      t.integer  "resource_id"
      t.string   "permissions"
      t.string   "owner"
      t.string   "group"
    end

    add_index "filesystems", ["miq_set_id"], :name => "index_filesystems_on_miq_set_id"
    add_index "filesystems", ["resource_type", "resource_id"], :name => "index_filesystems_on_resource_type_and_resource_id"
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
      t.integer  "operating_system_id"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "reserved"
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
      t.integer "vm_id"
      t.string  "product_key"
      t.string  "path",         :limit => 512
      t.text    "reserved"
      t.string  "arch"
      t.integer "host_id"
      t.string  "release"
    end

    add_index "guest_applications", ["typename"], :name => "index_guest_applications_on_typename"
    add_index "guest_applications", ["vm_id"], :name => "index_guest_applications_on_vm_id"

    create_table "guest_devices" do |t|
      t.string  "device_name"
      t.string  "device_type"
      t.string  "location"
      t.string  "filename"
      t.integer "hardware_id"
      t.string  "mode"
      t.string  "controller_type"
      numeric_column_with_db_differences(t, "size")
      numeric_column_with_db_differences(t, "free_space")
      numeric_column_with_db_differences(t, "size_on_disk")
      t.string  "address"
      t.integer "switch_id"
      t.integer "lan_id"
      t.string  "model"
      t.string  "iscsi_name"
      t.string  "iscsi_alias"
      t.boolean "present",         :default => true
      t.boolean "start_connected", :default => true
      t.boolean "auto_detect"
      t.text    "reserved"
      t.string  "uid_ems"
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
      t.integer "numvcpus",             :default => 1
      t.string  "bios"
      t.string  "bios_location"
      t.string  "time_sync"
      t.text    "annotation"
      t.integer "vm_id"
      t.integer "memory_cpu"
      t.integer "host_id"
      t.integer "cpu_speed"
      t.string  "cpu_type"
      numeric_column_with_db_differences(t, "size_on_disk")
      t.string  "manufacturer",         :default => ""
      t.string  "model",                :default => ""
      t.integer "number_of_nics"
      t.integer "cpu_usage"
      t.integer "memory_usage"
      t.integer "cores_per_socket"
      t.integer "logical_cpus"
      t.integer "vmotion_enabled"
      numeric_column_with_db_differences(t, "disk_free_space")
      numeric_column_with_db_differences(t, "disk_capacity")
      t.string  "guest_os_full_name"
      t.text    "reserved"
      t.integer "memory_console"
    end

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
      t.string   "guid",                  :limit => 36
      t.integer  "ems_id"
      t.string   "user_assigned_os"
      t.string   "power_state",                         :default => ""
      t.integer  "smart"
      t.string   "settings"
      t.datetime "last_perf_capture_on"
      t.text     "reserved"
      t.string   "uid_ems"
      t.string   "connection_state"
      t.string   "ssh_permit_root_login"
      t.string   "custom_1"
      t.string   "custom_2"
      t.string   "custom_3"
      t.string   "custom_4"
      t.string   "custom_5"
      t.string   "custom_6"
      t.string   "custom_7"
      t.string   "custom_8"
      t.string   "custom_9"
    end

    add_index "hosts", ["ems_id"], :name => "index_hosts_on_ems_id"
    add_index "hosts", ["guid"], :name => "index_hosts_on_guid", :unique => true
    add_index "hosts", ["hostname"], :name => "index_hosts_on_hostname"
    add_index "hosts", ["ipaddress"], :name => "index_hosts_on_ipaddress"

    create_table "hosts_storages", :id => false do |t|
      t.integer "storage_id"
      t.integer "host_id"
    end

    add_index "hosts_storages", ["host_id", "storage_id"], :name => "index_hosts_storages_on_host_id_and_storage_id", :unique => true

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
      t.integer  "target_id"
      t.string   "target_class"
      t.string   "process_type"
      t.binary   "process"
      t.integer  "agent_id"
      t.string   "agent_class"
      t.string   "agent_state"
      t.text     "agent_message"
      t.datetime "started_on"
      t.string   "dispatch_status"
      t.string   "sync_key"
      t.integer  "miq_server_id"
      t.text     "reserved"
      t.string   "zone"
      t.string   "agent_name"
      t.boolean  "archive"
    end

    add_index "jobs", ["agent_class", "agent_id"], :name => "index_jobs_on_agent_class_and_agent_id"
    add_index "jobs", ["dispatch_status"], :name => "index_jobs_on_dispatch_status"
    add_index "jobs", ["guid"], :name => "index_jobs_on_guid", :unique => true
    add_index "jobs", ["state"], :name => "index_jobs_on_state"

    create_table "lans" do |t|
      t.integer  "switch_id"
      t.string   "name"
      t.string   "tag"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "reserved"
      t.string   "uid_ems"
      t.boolean  "allow_promiscuous"
      t.boolean  "forged_transmits"
      t.boolean  "mac_changes"
      t.boolean  "computed_allow_promiscuous"
      t.boolean  "computed_forged_transmits"
      t.boolean  "computed_mac_changes"
    end

    add_index "lans", ["switch_id"], :name => "index_lans_on_switch_id"

    create_table "lifecycle_events" do |t|
      t.string   "guid"
      t.string   "status"
      t.string   "event"
      t.string   "message"
      t.string   "location"
      t.integer  "vm_id"
      t.string   "created_by"
      t.datetime "created_on"
      t.text     "reserved"
    end

    add_index "lifecycle_events", ["guid"], :name => "index_lifecycle_events_on_guid", :unique => true
    add_index "lifecycle_events", ["vm_id"], :name => "index_lifecycle_events_on_vm_id"

    create_table "log_files" do |t|
      t.string   "name"
      t.string   "description"
      t.string   "resource_type"
      t.integer  "resource_id"
      t.integer  "miq_task_id"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "reserved"
      t.datetime "logging_started_on"
      t.datetime "logging_ended_on"
      t.string   "state"
      t.boolean  "historical"
      t.string   "log_uri"
    end

    create_table "miq_actions" do |t|
      t.string   "name"
      t.string   "description"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "guid",        :limit => 36
      t.string   "action_type"
      t.text     "options"
      t.text     "reserved"
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
      t.text     "reserved"
      t.integer  "namespace_id"
    end

    create_table "miq_ae_fields" do |t|
      t.string   "aetype"
      t.string   "name"
      t.string   "display_name"
      t.string   "datatype"
      t.integer  "priority"
      t.string   "owner"
      t.text     "default_value"
      t.boolean  "substitute",    :default => true, :null => false
      t.text     "message"
      t.string   "visibility"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.integer  "class_id"
      t.text     "reserved"
      t.text     "collect"
      t.integer  "method_id"
      t.string   "scope"
      t.text     "description"
    end

    add_index "miq_ae_fields", ["class_id"], :name => "index_miq_ae_fields_on_ae_class_id"

    create_table "miq_ae_instances" do |t|
      t.string   "display_name"
      t.string   "name"
      t.string   "inherits"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.integer  "class_id"
      t.text     "reserved"
      t.text     "description"
    end

    add_index "miq_ae_instances", ["class_id"], :name => "index_miq_ae_instances_on_ae_class_id"

    create_table "miq_ae_methods" do |t|
      t.string   "name"
      t.integer  "class_id"
      t.string   "display_name"
      t.text     "description"
      t.string   "scope"
      t.string   "language"
      t.string   "location"
      t.text     "data"
      t.datetime "created_on"
      t.datetime "updated_on"
    end

    create_table "miq_ae_namespaces" do |t|
      t.integer  "parent_id"
      t.string   "name"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "reserved"
      t.text     "description"
    end

    create_table "miq_ae_values" do |t|
      t.integer  "instance_id"
      t.integer  "field_id"
      t.text     "value"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "reserved"
    end

    add_index "miq_ae_values", ["field_id"], :name => "index_miq_ae_values_on_field_id"
    add_index "miq_ae_values", ["instance_id"], :name => "index_miq_ae_values_on_instance_id"

    create_table "miq_ae_workspaces" do |t|
      t.string   "guid",       :limit => 36
      t.text     "uri"
      t.text     "workspace"
      t.text     "setters"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "reserved"
    end

    create_table "miq_alert_contents" do |t|
      t.integer  "miq_alert_id"
      t.integer  "miq_action_id"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.integer  "sequence"
      t.boolean  "synchronous"
      t.text     "reserved"
    end

    create_table "miq_alerts" do |t|
      t.string   "guid",        :limit => 36
      t.string   "description"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "options"
      t.string   "db"
      t.text     "expression"
      t.text     "reserved"
    end

    create_table "miq_approvals" do |t|
      t.string   "description"
      t.string   "state"
      t.string   "reason"
      t.integer  "miq_request_id"
      t.datetime "stamped_on"
      t.string   "stamper_name"
      t.integer  "stamper_id"
      t.integer  "approver_id"
      t.string   "approver_type"
      t.string   "approver_name"
      t.datetime "created_on"
      t.datetime "updated_on"
    end

    create_table "miq_enterprises" do |t|
      t.string   "name"
      t.string   "description"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "settings"
      t.text     "reserved"
    end

    create_table "miq_events" do |t|
      t.string   "name"
      t.string   "description"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "guid",        :limit => 36
      t.string   "event_type"
      t.text     "reserved"
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
      t.string   "guid",           :limit => 36
      t.string   "description"
      t.integer  "ui_task_set_id"
      t.string   "group_type"
      t.integer  "sequence"
      t.string   "resource_type"
      t.integer  "resource_id"
      t.text     "filters"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "reserved"
    end

    create_table "miq_license_contents" do |t|
      t.text     "contents"
      t.boolean  "active"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "reserved"
    end

    create_table "miq_policies" do |t|
      t.string   "name"
      t.string   "description"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "expression"
      t.string   "towhat"
      t.string   "guid",        :limit => 36
      t.text     "reserved"
      t.string   "created_by"
      t.string   "updated_by"
      t.string   "notes",       :limit => 512
      t.boolean  "active"
      t.string   "mode"
    end

    create_table "miq_policy_contents" do |t|
      t.integer  "miq_policy_id"
      t.integer  "miq_action_id"
      t.integer  "miq_event_id"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "qualifier"
      t.integer  "success_sequence"
      t.integer  "failure_sequence"
      t.boolean  "success_synchronous"
      t.boolean  "failure_synchronous"
      t.text     "reserved"
    end

    create_table "miq_provision_requests" do |t|
      t.string   "description"
      t.string   "state"
      t.string   "provision_type"
      t.string   "userid"
      t.text     "options"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "message"
      t.integer  "src_vm_id"
    end

    create_table "miq_provisions" do |t|
      t.string   "description"
      t.string   "state"
      t.string   "provision_type"
      t.string   "userid"
      t.text     "options"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "message"
      t.integer  "miq_provision_request_id"
      t.integer  "vm_id"
      t.integer  "src_vm_id"
    end

    create_table "miq_proxies" do |t|
      t.string   "guid",             :limit => 36
      t.string   "name"
      t.text     "settings"
      t.datetime "last_heartbeat"
      t.string   "version"
      t.string   "ws_port"
      t.integer  "host_id"
      t.integer  "vm_id"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "capabilities"
      t.string   "power_state"
      t.text     "reserved"
      t.string   "upgrade_status"
      t.string   "upgrade_message"
      t.text     "remote_config"
      t.string   "upgrade_settings"
    end

    add_index "miq_proxies", ["guid"], :name => "index_miq_proxies_on_guid", :unique => true
    add_index "miq_proxies", ["host_id"], :name => "index_miq_proxies_on_host_id"

    create_table "miq_proxies_product_updates", :id => false do |t|
      t.integer "product_update_id"
      t.integer "miq_proxy_id"
    end

    create_table "miq_queue" do |t|
      t.integer  "target_id"
      t.integer  "priority"
      t.string   "method_name"
      t.string   "state"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.integer  "lock_version",                :default => 0
      t.string   "task_id",       :limit => 36
      t.string   "md5"
      t.datetime "deliver_on"
      t.string   "queue_name"
      t.string   "class_name"
      t.integer  "instance_id"
      t.text     "args"
      t.text     "miq_callback"
      t.binary   "msg_data"
      t.string   "zone"
      t.string   "role"
      t.string   "server_guid",   :limit => 36
      t.integer  "msg_timeout"
      t.text     "reserved"
      t.integer  "miq_worker_id"
    end

    add_index "miq_queue", ["queue_name"], :name => "index_miq_queue_on_queue_name"
    add_index "miq_queue", ["role"], :name => "index_miq_queue_on_role"
    add_index "miq_queue", ["server_guid"], :name => "index_miq_queue_on_server_guid"
    add_index "miq_queue", ["state"], :name => "index_miq_queue_on_state"
    add_index "miq_queue", ["task_id"], :name => "index_miq_queue_on_task_id"
    add_index "miq_queue", ["zone"], :name => "index_miq_queue_on_zone"

    create_table "miq_report_results" do |t|
      t.string   "name"
      t.integer  "miq_report_id"
      t.integer  "miq_task_id"
      t.string   "userid"
      t.string   "report_source"
      t.string   "db"
      t.text     "report"
      t.datetime "created_on"
      t.datetime "scheduled_on"
      t.datetime "last_run_on"
      t.text     "reserved"
    end

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
      t.text     "reserved"
      t.text     "db_options"
      t.text     "generate_cols"
      t.text     "generate_rows"
      t.text     "col_formats"
      t.string   "tz"
      t.integer  "time_profile_id"
      t.text     "display_filter"
      t.text     "col_options"
      t.text     "rpt_options"
    end

    add_index "miq_reports", ["db"], :name => "index_miq_reports_on_db"
    add_index "miq_reports", ["rpt_type"], :name => "index_miq_reports_on_rpt_type"
    add_index "miq_reports", ["template_type"], :name => "index_miq_reports_on_template_type"

    create_table "miq_requests" do |t|
      t.string   "description"
      t.string   "state"
      t.string   "resource_type"
      t.integer  "resource_id"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.datetime "fulfilled_on"
      t.integer  "requester_id"
      t.string   "requester_name"
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
      t.datetime "last_update_on"
      t.text     "reserved"
      t.integer  "miq_search_id"
      t.integer  "zone_id"
    end

    create_table "miq_scsi_luns" do |t|
      t.integer "miq_scsi_target_id"
      t.integer "lun"
      t.string  "canonical_name"
      t.string  "lun_type"
      t.string  "device_name"
      t.bigint  "block"
      t.integer "block_size"
      t.bigint  "capacity"
      t.string  "device_type"
      t.string  "uid_ems"
      t.text    "reserved"
    end

    add_index "miq_scsi_luns", ["miq_scsi_target_id"], :name => "index_miq_scsi_luns_on_miq_scsi_target_id"

    create_table "miq_scsi_targets" do |t|
      t.integer "guest_device_id"
      t.integer "target"
      t.string  "iscsi_name"
      t.string  "iscsi_alias"
      t.string  "address"
      t.text    "reserved"
      t.string  "uid_ems"
    end

    add_index "miq_scsi_targets", ["guest_device_id"], :name => "index_miq_scsi_targets_on_guest_device_id"

    create_table "miq_searches" do |t|
      t.string "name"
      t.string "description"
      t.text   "options"
      t.text   "filter"
      t.string "db"
      t.text   "reserved"
      t.string "search_type"
      t.string "search_key"
    end

    create_table "miq_servers" do |t|
      t.string   "guid",            :limit => 36
      t.string   "status"
      t.datetime "started_on"
      t.datetime "stopped_on"
      t.integer  "pid"
      t.string   "build"
      t.float    "percent_memory"
      t.float    "percent_cpu"
      t.string   "cpu_time"
      t.string   "name"
      t.text     "capabilities"
      t.datetime "last_heartbeat"
      t.integer  "os_priority"
      t.boolean  "is_master",                                                    :default => false
      t.binary   "logo"
      t.string   "version"
      t.text     "reserved"
      t.integer  "zone_id"
      t.string   "upgrade_status"
      t.string   "upgrade_message"
      t.decimal  "memory_usage",                  :precision => 20, :scale => 0
      t.decimal  "memory_size",                   :precision => 20, :scale => 0
      t.string   "hostname"
      t.string   "ipaddress"
      t.string   "message"
    end

    add_index "miq_servers", ["guid"], :name => "index_miq_servers_on_guid", :unique => true

    create_table "miq_servers_product_updates", :id => false do |t|
      t.integer "product_update_id"
      t.integer "miq_server_id"
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
      t.text     "reserved"
      t.string   "mode"
    end

    add_index "miq_sets", ["guid"], :name => "index_miq_sets_on_guid", :unique => true
    add_index "miq_sets", ["name"], :name => "index_miq_sets_on_name"
    add_index "miq_sets", ["set_type"], :name => "index_miq_sets_on_set_type"

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
      t.integer  "miq_server_id"
      t.text     "reserved"
    end

    create_table "miq_workers" do |t|
      t.string   "guid",           :limit => 36
      t.string   "status"
      t.datetime "started_on"
      t.datetime "stopped_on"
      t.datetime "last_heartbeat"
      t.integer  "pid"
      t.string   "message"
      t.string   "queue_name"
      t.string   "type"
      t.string   "command_line",   :limit => 512
      t.float    "percent_memory"
      t.float    "percent_cpu"
      t.string   "cpu_time"
      t.integer  "os_priority"
      t.text     "reserved"
      t.string   "monitor_status"
      t.decimal  "memory_usage",                  :precision => 20, :scale => 0
      t.decimal  "memory_size",                   :precision => 20, :scale => 0
      t.string   "drb_uri"
      t.integer  "miq_server_id"
    end

    add_index "miq_workers", ["guid"], :name => "index_miq_workers_on_guid", :unique => true
    add_index "miq_workers", ["miq_server_id"], :name => "index_miq_workers_on_miq_server_id"
    add_index "miq_workers", ["queue_name"], :name => "index_miq_workers_on_queue_name"
    add_index "miq_workers", ["status"], :name => "index_miq_workers_on_status"
    add_index "miq_workers", ["type"], :name => "index_miq_workers_on_worker_type"

    create_table "networks" do |t|
      t.integer  "hardware_id"
      t.integer  "device_id"
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
      t.text     "reserved"
    end

    add_index "networks", ["device_id"], :name => "index_networks_on_device_id"
    add_index "networks", ["hardware_id"], :name => "index_networks_on_hardware_id"

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
      t.integer "vm_id"
      t.integer "host_id"
      t.integer "bitness"
      t.string  "product_key"
      t.integer "pw_hist"
      t.integer "max_pw_age"
      t.integer "min_pw_age"
      t.integer "min_pw_len"
      t.boolean "pw_complex"
      t.boolean "pw_encrypt"
      t.integer "lockout_threshold"
      t.integer "lockout_duration"
      t.integer "reset_lockout_counter"
      t.string  "system_type"
      t.text    "reserved"
    end

    add_index "operating_systems", ["host_id"], :name => "index_operating_systems_on_host_id"
    add_index "operating_systems", ["vm_id"], :name => "index_operating_systems_on_vm_id"

    create_table "os_processes" do |t|
      t.string   "name"
      t.integer  "pid"
      t.bigint   "memory_usage"
      t.bigint   "memory_size"
      t.float    "percent_memory"
      t.float    "percent_cpu"
      t.integer  "cpu_time"
      t.integer  "priority"
      t.integer  "operating_system_id"
      t.datetime "created_on"
      t.datetime "updated_on"
    end

    create_table "partitions" do |t|
      t.integer  "disk_id"
      t.string   "name"
      numeric_column_with_db_differences(t, "size")
      numeric_column_with_db_differences(t, "free_space")
      numeric_column_with_db_differences(t, "used_space")
      t.datetime "created_on"
      t.datetime "updated_on"
      t.integer  "location"
      t.integer  "hardware_id"
      t.string   "volume_group"
      t.integer  "partition_type"
      t.string   "controller"
      t.string   "virtual_disk_file"
      t.string   "uid"
      t.text     "reserved"
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
      t.integer  "vm_id"
      t.integer  "host_id"
      t.datetime "installed_on"
      t.text     "reserved"
    end

    add_index "patches", ["host_id"], :name => "index_patches_on_host_id"
    add_index "patches", ["vm_id"], :name => "index_patches_on_vm_id"

    create_table "policy_event_contents" do |t|
      t.integer "policy_event_id"
      t.integer "resource_id"
      t.string  "resource_type"
      t.string  "resource_description"
      t.text    "reserved"
    end

    create_table "policy_events" do |t|
      t.integer  "miq_event_id"
      t.string   "event_type"
      t.string   "miq_event_description"
      t.integer  "miq_policy_id"
      t.string   "miq_policy_description"
      t.string   "result"
      t.datetime "timestamp"
      t.integer  "target_id"
      t.string   "target_class"
      t.string   "target_name"
      t.integer  "chain_id"
      t.string   "username"
      t.text     "reserved"
      t.integer  "host_id"
      t.integer  "ems_cluster_id"
      t.integer  "ems_id"
    end

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
      t.integer  "miq_proxy_id"
      t.text     "reserved"
    end

    add_index "proxy_tasks", ["miq_proxy_id"], :name => "index_proxy_tasks_on_miq_proxy_id"

    create_table "registry_items" do |t|
      t.integer  "miq_set_id"
      t.integer  "scan_item_id"
      t.integer  "vm_id"
      t.string   "name"
      t.text     "data"
      t.string   "format"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "value_name"
      t.text     "reserved"
    end

    add_index "registry_items", ["miq_set_id"], :name => "index_registry_items_on_miq_set_id"
    add_index "registry_items", ["scan_item_id"], :name => "index_registry_items_on_scan_item_id"
    add_index "registry_items", ["vm_id"], :name => "index_registry_items_on_vm_id"

    create_table "relationships" do |t|
      t.integer  "parent_id"
      t.integer  "child_id"
      t.string   "parent_type"
      t.string   "child_type"
      t.string   "operation"
      t.string   "operation_type"
      t.string   "user_id"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "relationship"
      t.text     "reserved"
    end

    add_index "relationships", ["child_type", "child_id"], :name => "index_relationships_on_child_type_and_child_id"
    add_index "relationships", ["parent_type", "parent_id"], :name => "index_relationships_on_parent_type_and_parent_id"
    add_index "relationships", ["relationship"], :name => "index_relationships_on_relationship"

    create_table "repositories" do |t|
      t.string   "name"
      t.string   "relative_path"
      t.integer  "storage_id"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "reserved"
    end

    add_index "repositories", ["storage_id"], :name => "index_repositories_on_storage_id"

    create_table "reserves" do |t|
      t.string  "resource_type"
      t.integer "resource_id"
      t.text    "reserved"
    end

    create_table "resource_pools" do |t|
      t.string   "name"
      t.integer  "ems_id"
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
      t.text     "reserved"
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
      t.text     "reserved"
    end

    add_index "rss_feeds", ["name"], :name => "index_rss_feeds_on_name"

    create_table "scan_histories" do |t|
      t.integer  "vm_id"
      t.string   "status"
      t.text     "message"
      t.datetime "started_on"
      t.datetime "finished_on"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "task_id",     :limit => 36
      t.integer  "status_code"
      t.text     "reserved"
    end

    add_index "scan_histories", ["vm_id"], :name => "index_scan_histories_on_vm_id"

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
      t.text     "reserved"
      t.string   "mode"
    end

    add_index "scan_items", ["guid"], :name => "index_scan_items_on_guid", :unique => true
    add_index "scan_items", ["item_type"], :name => "index_scan_items_on_item_type"
    add_index "scan_items", ["name"], :name => "index_scan_items_on_name"

    create_table "server_roles" do |t|
      t.string   "name"
      t.string   "description"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "license_required"
      t.integer  "max_concurrent"
      t.boolean  "external_failover"
      t.text     "reserved"
    end

    create_table "services" do |t|
      t.string   "name"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "created_by"
      t.string   "icon"
      t.text     "reserved"
    end

    create_table "sessions" do |t|
      t.string   "session_id"
      t.text     "data"
      t.datetime "updated_at"
      t.text     "reserved"
    end

    add_index "sessions", ["session_id"], :name => "index_sessions_on_session_id"
    add_index "sessions", ["updated_at"], :name => "index_sessions_on_updated_at"

    create_table "snapshots" do |t|
      t.string   "uid"
      t.string   "parent_uid"
      t.string   "name"
      t.text     "description"
      t.integer  "current"
      numeric_column_with_db_differences(t, "total_size")
      t.string   "filename"
      t.datetime "create_time"
      t.text     "disks"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.integer  "parent_id"
      t.integer  "vm_id"
      t.string   "uid_ems"
      t.text     "reserved"
    end

    add_index "snapshots", ["parent_id"], :name => "index_snapshots_on_parent_id"
    add_index "snapshots", ["parent_uid"], :name => "index_snapshots_on_parent_uid"
    add_index "snapshots", ["uid"], :name => "index_snapshots_on_uid"
    add_index "snapshots", ["vm_id"], :name => "index_snapshots_on_vm_id"

    create_table "states" do |t|
      t.string   "name"
      t.datetime "timestamp"
      t.datetime "created_on"
      t.text     "stats"
      t.string   "scantype"
      t.integer  "resource_id"
      t.string   "resource_type"
      t.text     "xml_data"
      t.string   "md5"
      t.text     "reserved"
    end

    add_index "states", ["resource_type", "resource_id"], :name => "index_states_on_resource_type_and_resource_id"
    add_index "states", ["scantype"], :name => "index_states_on_scantype"
    add_index "states", ["timestamp"], :name => "index_states_on_timestamp"

    create_table "storage_files" do |t|
      t.text     "name"
      t.string   "size"
      t.datetime "mtime"
      t.string   "rsc_type"
      t.text     "base_name"
      t.string   "ext_name"
      t.integer  "storage_id"
      t.integer  "vm_id"
      t.text     "reserved"
    end

    create_table "storages" do |t|
      t.string   "name"
      t.string   "store_type"
      numeric_column_with_db_differences(t, "total_space")
      numeric_column_with_db_differences(t, "free_space")
      t.datetime "created_on"
      t.datetime "updated_on"
      t.integer  "multiplehostaccess"
      t.string   "location",             :default => ""
      t.text     "reserved"
      t.datetime "last_scan_on"
      t.bigint   "uncommitted"
      t.datetime "last_perf_capture_on"
    end

    add_index "storages", ["location"], :name => "index_storages_on_location"
    add_index "storages", ["name"], :name => "index_storages_on_name"

    create_table "switches" do |t|
      t.integer  "host_id"
      t.string   "name"
      t.integer  "ports"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "reserved"
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
      t.integer "vm_id"
      t.string  "enable_run_levels"
      t.string  "disable_run_levels"
      t.text    "reserved"
      t.integer "host_id"
      t.boolean "running"
    end

    add_index "system_services", ["host_id"], :name => "index_system_services_on_host_id"
    add_index "system_services", ["typename"], :name => "index_system_services_on_typename"
    add_index "system_services", ["vm_id"], :name => "index_system_services_on_vm_id"

    create_table "taggings" do |t|
      t.integer "taggable_id"
      t.integer "tag_id"
      t.string  "taggable_type"
      t.text    "reserved"
    end

    add_index "taggings", ["tag_id"], :name => "index_taggings_on_tag_id"
    add_index "taggings", ["taggable_type", "taggable_id"], :name => "index_taggings_on_taggable_type_and_taggable_id"

    create_table "tags" do |t|
      t.text "name"
      t.text "reserved"
    end

    create_table "time_profiles" do |t|
      t.string   "description"
      t.string   "profile_type"
      t.string   "profile_key"
      t.text     "profile"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "reserved"
    end

    create_table "ui_tasks" do |t|
      t.string   "name"
      t.string   "area"
      t.string   "typ"
      t.string   "task"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "reserved"
    end

    add_index "ui_tasks", ["area", "typ", "task"], :name => "index_ui_tasks_on_area_and_typ_and_task"

    create_table "users" do |t|
      t.string   "name"
      t.string   "email"
      t.string   "icon"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "password"
      t.string   "userid"
      t.text     "settings"
      t.text     "filters"
      t.integer  "ui_task_set_id"
      t.datetime "lastlogon"
      t.datetime "lastlogoff"
      t.text     "reserved"
    end

    add_index "users", ["ui_task_set_id"], :name => "index_users_on_ui_task_set_id"
    add_index "users", ["userid"], :name => "index_users_on_userid", :unique => true

    create_table "vim_performance_counters" do |t|
      t.string  "group_info"
      t.string  "name_info"
      t.string  "stats"
      t.string  "rollup"
      t.string  "instance"
      t.integer "capture_interval"
      t.string  "group_label"
      t.string  "name_label"
      t.string  "unit_key"
      t.string  "unit_label"
      t.string  "vim_key"
      t.string  "capture_interval_name"
      t.text    "reserved"
    end

    create_table "vim_performance_metrics" do |t|
      t.integer  "resource_id"
      t.string   "resource_type"
      t.text     "reserved"
      t.text     "counter_values"
      t.string   "capture_interval_name"
      t.datetime "start_timestamp"
      t.datetime "end_timestamp"
    end

    add_index "vim_performance_metrics", ["resource_type", "resource_id"], :name => "index_vim_performance_metrics_on_resource_type_and_resource_id"

    create_table "vim_performance_states" do |t|
      t.datetime "timestamp"
      t.integer  "capture_interval"
      t.string   "resource_type"
      t.integer  "resource_id"
      t.text     "state_data"
      t.text     "reserved"
    end

    add_index "vim_performance_states", ["resource_type", "resource_id", "timestamp"], :name => "index_vim_performance_states_on_resource_and_timestamp"

    create_table "vim_performance_tag_values" do |t|
      t.integer "vim_performance_id"
      t.string  "association_type"
      t.string  "category"
      t.string  "tag_name"
      t.string  "column_name"
      t.float   "value"
      t.text    "assoc_ids"
      t.text    "reserved"
    end

    add_index "vim_performance_tag_values", ["vim_performance_id"], :name => "index_vim_performance_tag_values_on_vim_performance_id"

    create_table "vim_performances" do |t|
      t.datetime "timestamp"
      t.integer  "capture_interval"
      t.string   "resource_type"
      t.integer  "resource_id"
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
      t.integer  "parent_host_id"
      t.integer  "parent_ems_cluster_id"
      t.integer  "parent_storage_id"
      t.integer  "parent_ems_id"
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
      t.text     "reserved"
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
    end

    add_index "vim_performances", ["capture_interval_name", "resource_type", "resource_id", "timestamp"], :name => "index_vim_performances_on_resource_and_timestamp"

    create_table "vms" do |t|
      t.string   "vendor"
      t.string   "format"
      t.string   "version"
      t.string   "name"
      t.text     "description"
      t.string   "location"
      t.string   "config_xml"
      t.string   "autostart"
      t.integer  "host_id"
      t.datetime "last_sync_on"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.integer  "storage_id"
      t.string   "guid",                  :limit => 36
      t.integer  "service_id"
      t.integer  "ems_id"
      t.datetime "last_scan_on"
      t.datetime "last_scan_attempt_on"
      t.string   "uid_ems"
      t.date     "retires_on"
      t.boolean  "retired"
      t.datetime "boot_time"
      t.string   "tools_status"
      t.string   "standby_action"
      t.string   "custom_1"
      t.string   "custom_2"
      t.string   "custom_3"
      t.string   "custom_4"
      t.string   "custom_5"
      t.string   "custom_6"
      t.string   "custom_7"
      t.string   "custom_8"
      t.string   "custom_9"
      t.string   "power_state"
      t.datetime "state_changed_on"
      t.string   "previous_state"
      t.string   "connection_state"
      t.text     "reserved"
      t.datetime "last_perf_capture_on"
      t.boolean  "blackbox_exists"
      t.boolean  "blackbox_validated"
      t.boolean  "registered"
      t.boolean  "busy"
      t.boolean  "smart"
      t.text     "owner"
      t.text     "retirement"
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
      t.integer  "evm_owner_id"
    end

    add_index "vms", ["ems_id"], :name => "index_vms_on_ems_id"
    add_index "vms", ["guid"], :name => "index_vms_on_guid", :unique => true
    add_index "vms", ["host_id"], :name => "index_vms_on_host_id"
    add_index "vms", ["location"], :name => "index_vms_on_location"
    add_index "vms", ["name"], :name => "index_vms_on_name"
    add_index "vms", ["service_id"], :name => "index_vms_on_service_id"
    add_index "vms", ["storage_id"], :name => "index_vms_on_storage_id"
    add_index "vms", ["uid_ems"], :name => "index_vms_on_vmm_uuid"

    create_table "volumes" do |t|
      t.string   "name"
      t.string   "typ"
      t.string   "filesystem"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.integer  "hardware_id"
      t.string   "volume_group"
      t.string   "uid"
      numeric_column_with_db_differences(t, "size")
      numeric_column_with_db_differences(t, "free_space")
      numeric_column_with_db_differences(t, "used_space")
      t.text     "reserved"
    end

    add_index "volumes", ["hardware_id", "volume_group"], :name => "index_volumes_on_hardware_id_and_volume_group"

    create_table "zones" do |t|
      t.string   "name"
      t.string   "description"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "reserved"
      t.text     "settings"
    end

    create_performances_views
  end

  def down
    drop_performances_views

    drop_table "zones"
    drop_table "volumes"
    drop_table "vms"
    drop_table "vim_performances"
    drop_table "vim_performance_tag_values"
    drop_table "vim_performance_states"
    drop_table "vim_performance_metrics"
    drop_table "vim_performance_counters"
    drop_table "users"
    drop_table "ui_tasks"
    drop_table "time_profiles"
    drop_table "tags"
    drop_table "taggings"
    drop_table "system_services"
    drop_table "switches"
    drop_table "storages"
    drop_table "storage_files"
    drop_table "states"
    drop_table "snapshots"
    drop_table "sessions"
    drop_table "services"
    drop_table "server_roles"
    drop_table "scan_items"
    drop_table "scan_histories"
    drop_table "rss_feeds"
    drop_table "resource_pools"
    drop_table "reserves"
    drop_table "repositories"
    drop_table "relationships"
    drop_table "registry_items"
    drop_table "proxy_tasks"
    drop_table "product_updates"
    drop_table "policy_events"
    drop_table "policy_event_contents"
    drop_table "patches"
    drop_table "partitions"
    drop_table "os_processes"
    drop_table "operating_systems"
    drop_table "networks"
    drop_table "miq_workers"
    drop_table "miq_tasks"
    drop_table "miq_sets"
    drop_table "miq_servers_product_updates"
    drop_table "miq_servers"
    drop_table "miq_searches"
    drop_table "miq_scsi_targets"
    drop_table "miq_scsi_luns"
    drop_table "miq_schedules"
    drop_table "miq_requests"
    drop_table "miq_reports"
    drop_table "miq_report_results"
    drop_table "miq_queue"
    drop_table "miq_proxies_product_updates"
    drop_table "miq_proxies"
    drop_table "miq_provisions"
    drop_table "miq_provision_requests"
    drop_table "miq_policy_contents"
    drop_table "miq_policies"
    drop_table "miq_license_contents"
    drop_table "miq_groups"
    drop_table "miq_globals"
    drop_table "miq_events"
    drop_table "miq_enterprises"
    drop_table "miq_approvals"
    drop_table "miq_alerts"
    drop_table "miq_alert_contents"
    drop_table "miq_ae_workspaces"
    drop_table "miq_ae_values"
    drop_table "miq_ae_namespaces"
    drop_table "miq_ae_methods"
    drop_table "miq_ae_instances"
    drop_table "miq_ae_fields"
    drop_table "miq_ae_classes"
    drop_table "miq_actions"
    drop_table "log_files"
    drop_table "lifecycle_events"
    drop_table "lans"
    drop_table "jobs"
    drop_table "hosts_storages"
    drop_table "hosts"
    drop_table "hardwares"
    drop_table "guest_devices"
    drop_table "guest_applications"
    drop_table "firewall_rules"
    drop_table "filesystems"
    drop_table "ext_management_systems"
    drop_table "event_logs"
    drop_table "ems_folders"
    drop_table "ems_events"
    drop_table "ems_clusters"
    drop_table "disks"
    drop_table "custom_attributes"
    drop_table "configurations"
    drop_table "conditions_miq_policies"
    drop_table "conditions"
    drop_table "compliances"
    drop_table "compliance_details"
    drop_table "classifications"
    drop_table "bottleneck_events"
    drop_table "binary_blobs"
    drop_table "binary_blob_parts"
    drop_table "automation_uris"
    drop_table "authentications"
    drop_table "audit_events"
    drop_table "assigned_server_roles"
    drop_table "advanced_settings"
    drop_table "accounts"

    say_with_time("Clean old migrations from schema_migrations") do
      connection.truncate("schema_migrations")
    end
  end

  def numeric_column_with_db_differences(t, column)
    if sqlserver?
      t.decimal column, :precision => 20, :scale => 0
    else
      t.bigint  column
    end
  end
end
