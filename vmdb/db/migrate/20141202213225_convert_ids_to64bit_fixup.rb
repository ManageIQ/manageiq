require Rails.root.join('lib/migration_helper')

class ConvertIdsTo64bitFixup < ActiveRecord::Migration
  include MigrationHelper

  disable_ddl_transaction!

  TABLES = [
    :availability_zones,                 [:ems_id],
    :cloud_networks,                     [:ems_id],
    :cloud_object_store_containers,      [:ems_id, :cloud_tenant_id],
    :cloud_object_store_objects,         [:ems_id, :cloud_tenant_id, :cloud_object_store_container_id],
    :cloud_resource_quotas,              [:ems_id, :cloud_tenant_id],
    :cloud_subnets,                      [:ems_id, :availability_zone_id, :cloud_network_id],
    :cloud_tenants,                      [:ems_id],
    :cloud_volume_snapshots,             [:ems_id, :cloud_volume_id],
    :cloud_volumes,                      [:ems_id, :availability_zone_id, :cloud_volume_snapshot_id],
    :flavors,                            [:ems_id],
    :iso_datastores,                     [:ems_id],
    :iso_images,                         [:iso_datastore_id, :pxe_image_type_id],
    :ldap_domains,                       [:ldap_domain_id],
    :ldap_groups,                        [:ldap_domain_id],
    :ldap_regions,                       [:zone_id],
    :ldap_servers,                       [:ldap_domain_id],
    :ldap_users,                         [:ldap_domain_id],
    :miq_widget_shortcuts,               [:miq_shortcut_id, :miq_widget_id],
    :orchestration_stack_outputs,        [:stack_id],
    :orchestration_stack_parameters,     [:stack_id],
    :orchestration_stack_resources,      [:stack_id],
    :orchestration_stacks,               [:ems_id, :orchestration_template_id],
    :pictures,                           [:resource_id],
    :pxe_menus,                          [:pxe_server_id],
    :resource_actions,                   [:dialog_id, :resource_id],
    :security_groups,                    [:ems_id],
    :service_resources,                  [:service_template_id, :resource_id],
    :service_templates,                  [:service_template_id],
    :services,                           [:service_template_id],
    :vim_performance_operating_ranges,   [:resource_id],
    :vmdb_database_metrics,              [:vmdb_database_id],
    :vmdb_indexes,                       [:vmdb_table_id],
    :vmdb_metrics,                       [:resource_id],
    :vmdb_tables,                        [:vmdb_database_id],
    :windows_images,                     [:pxe_server_id],
  ]

  INDEXES = [
    [:availability_zones,                 [:ems_id]],
    [:cloud_networks,                     [:ems_id]],
    [:cloud_object_store_containers,      [:ems_id]],
    [:cloud_object_store_containers,      [:cloud_tenant_id]],
    [:cloud_object_store_objects,         [:ems_id]],
    [:cloud_object_store_objects,         [:cloud_tenant_id]],
    [:cloud_object_store_objects,         [:cloud_object_store_container_id], {:name => "index_cloud_object_store_objects_on_container_id"}],
    [:cloud_resource_quotas,              [:ems_id]],
    [:cloud_resource_quotas,              [:cloud_tenant_id]],
    [:cloud_subnets,                      [:ems_id]],
    [:cloud_subnets,                      [:availability_zone_id]],
    [:cloud_subnets,                      [:cloud_network_id]],
    [:cloud_tenants,                      [:ems_id]],
    [:cloud_volume_snapshots,             [:ems_id]],
    [:cloud_volume_snapshots,             [:cloud_volume_id]],
    [:cloud_volumes,                      [:ems_id]],
    [:cloud_volumes,                      [:availability_zone_id]],
    [:cloud_volumes,                      [:cloud_volume_snapshot_id]],
    [:flavors,                            [:ems_id]],
    [:iso_datastores,                     [:ems_id]],
    [:iso_images,                         [:iso_datastore_id]],
    [:iso_images,                         [:pxe_image_type_id]],
    [:ldap_domains,                       [:ldap_domain_id]],
    [:ldap_groups,                        [:ldap_domain_id]],
    [:ldap_regions,                       [:zone_id]],
    [:ldap_servers,                       [:ldap_domain_id]],
    [:ldap_users,                         [:ldap_domain_id]],
    [:miq_widget_shortcuts,               [:miq_shortcut_id]],
    [:miq_widget_shortcuts,               [:miq_widget_id]],
    [:orchestration_stack_outputs,        [:stack_id]],
    [:orchestration_stack_parameters,     [:stack_id]],
    [:orchestration_stack_resources,      [:stack_id]],
    [:orchestration_stacks,               [:ems_id]],
    [:orchestration_stacks,               [:orchestration_template_id]],
    [:pictures,                           [:resource_id, :resource_type]],
    [:pxe_menus,                          [:pxe_server_id]],
    [:resource_actions,                   [:dialog_id]],
    [:resource_actions,                   [:resource_id, :resource_type]],
    [:security_groups,                    [:ems_id]],
    [:service_resources,                  [:service_template_id]],
    [:service_resources,                  [:resource_id, :resource_type]],
    [:service_templates,                  [:service_template_id]],
    [:services,                           [:service_template_id]],
    [:vim_performance_operating_ranges,   [:resource_id, :resource_type], {:name => "index_vpor_on_resource"}],
    [:vmdb_database_metrics,              [:vmdb_database_id]],
    [:vmdb_indexes,                       [:vmdb_table_id]],
    [:vmdb_metrics,                       [:resource_id, :resource_type]],
    [:vmdb_tables,                        [:vmdb_database_id]],
    [:windows_images,                     [:pxe_server_id]],
  ]

  def self.up
    # For performance reasons drop an existing index before changing the column
    INDEXES.each do |args|
      remove_index_ex(*args) if index_exists?(*args)
    end

    TABLES.each_slice(2) do |table, id_cols|
      change_id_columns table, id_cols, :bigint
    end

    # Add the index back unconditionally
    INDEXES.each do |args|
      add_index(*args)
    end
  end

  def self.down
    INDEXES.each do |args|
      remove_index_ex(*args) if index_exists?(*args)
    end

    TABLES.each_slice(2) do |table, id_cols|
      change_id_columns table, id_cols, :integer
    end

    INDEXES.each do |args|
      add_index(*args)
    end
  end
end
