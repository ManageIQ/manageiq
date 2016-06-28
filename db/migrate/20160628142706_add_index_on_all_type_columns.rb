class AddIndexOnAllTypeColumns < ActiveRecord::Migration[5.0]
  def change
    add_index :authentications, :type
    add_index :availability_zones, :type
    add_index :cloud_database_flavors, :type
    add_index :cloud_databases, :type
    add_index :cloud_networks, :type
    add_index :cloud_resource_quotas, :type
    add_index :cloud_subnets, :type
    add_index :cloud_tenants, :type
    add_index :cloud_volume_snapshots, :type
    add_index :cloud_volumes, :type
# no STI for configuration_locations ?
#    add_index :configuration_locations, :type
# no STI for configuration_organizations ?
#    add_index :configuration_organizations, :type
    add_index :configuration_profiles, :type
    add_index :configuration_scripts, :type
    add_index :configuration_tags, :type
    add_index :configured_systems, :type
    add_index :container_groups, :type
    add_index :container_nodes, :type
    add_index :container_volumes, :type
    add_index :containers, :type
    add_index :customization_scripts, :type
    add_index :customization_templates, :type
    add_index :dialog_fields, :type
    add_index :ems_clusters, :type
    add_index :ems_folders, :type
    add_index :event_streams, :type
    add_index :ext_management_systems, :type
    add_index :file_depots, :type
    add_index :flavors, :type
    add_index :floating_ips, :type
    add_index :git_references, :type
    add_index :host_service_groups, :type
    add_index :hosts, :type
    add_index :jobs, :type
# app/models/miq_ae_class.rb does not exist
#    add_index :miq_ae_classes, :type
    add_index :miq_request_tasks, :type
    add_index :miq_requests, :type
    add_index :miq_storage_metrics, :type
    add_index :network_groups, :type
    add_index :network_ports, :type
    add_index :network_routers, :type
    add_index :orchestration_stacks, :type
    add_index :orchestration_templates, :type
    add_index :providers, :type
    add_index :pxe_images, :type
    add_index :pxe_menus, :type
# no STI for resource_groups ?
#    add_index :resource_groups, :type
    add_index :security_groups, :type
    add_index :service_templates, :type
    add_index :services, :type
    add_index :storage_managers, :type
# app/models/storage_metrics_metadatum.rb does not exist
#    add_index :storage_metrics_metadata, :type
    add_index :vmdb_tables, :type
    add_index :vms, :type
  end
end
