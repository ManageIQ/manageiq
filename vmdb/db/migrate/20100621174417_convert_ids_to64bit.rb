require Rails.root.join('lib/migration_helper')

class ConvertIdsTo64bit < ActiveRecord::Migration
  include MigrationHelper
  include MigrationHelper::PerformancesViews

  disable_ddl_transaction!

  TABLES = [
    :accounts,                         [:id, :vm_id, :host_id],
    :advanced_settings,                [:id, :resource_id],
    :assigned_server_roles,            [:id, :miq_server_id, :server_role_id],
    :audit_events,                     [:id, :target_id],
    :authentications,                  [:id, :resource_id],
    :automation_uris,                  [:id, :button_id],
    :binary_blob_parts,                [:id, :binary_blob_id],
    :binary_blobs,                     [:id, :resource_id],
    :bottleneck_events,                [:id, :resource_id],
    :chargeback_rate_details,          [:id, :chargeback_rate_id],
    :chargeback_rates,                 [:id],
    :classifications,                  [:id, :tag_id, :parent_id],
    :compliance_details,               [:id, :compliance_id, :miq_policy_id, :condition_id],
    :compliances,                      [:id, :resource_id],
    :conditions,                       [:id, :miq_policy_id],
    :conditions_miq_policies,          [:miq_policy_id, :condition_id],
    :configurations,                   [:id, :miq_server_id],
    :custom_attributes,                [:id, :resource_id],
    :disks,                            [:id, :hardware_id, :storage_id],
    :ems_clusters,                     [:id, :ems_id],
    :ems_folders,                      [:id, :ems_id],
    :event_logs,                       [:id, :event_id, :operating_system_id],
    :ext_management_systems,           [:id, :zone_id],
    :filesystems,                      [:id, :miq_set_id, :scan_item_id, :resource_id],
    :firewall_rules,                   [:id, :operating_system_id],
    :guest_applications,               [:id, :vm_id, :host_id],
    :guest_devices,                    [:id, :hardware_id, :switch_id, :lan_id],
    :hardwares,                        [:id, :vm_id, :host_id],
    :hosts,                            [:id, :ems_id],
    :hosts_storages,                   [:storage_id, :host_id],
    :jobs,                             [:id, :target_id, :agent_id, :miq_server_id],
    :lans,                             [:id, :switch_id],
    :lifecycle_events,                 [:id, :vm_id],
    :log_files,                        [:id, :resource_id, :miq_task_id],
    :miq_actions,                      [:id],
    :miq_ae_classes,                   [:id, :namespace_id],
    :miq_ae_fields,                    [:id, :class_id, :method_id],
    :miq_ae_instances,                 [:id, :class_id],
    :miq_ae_methods,                   [:id, :class_id],
    :miq_ae_namespaces,                [:id, :parent_id],
    :miq_ae_values,                    [:id, :instance_id, :field_id],
    :miq_ae_workspaces,                [:id],
    :miq_alert_statuses,               [:id, :miq_alert_id, :resource_id],
    :miq_alerts,                       [:id],
    :miq_approvals,                    [:id, :miq_request_id, :stamper_id, :approver_id],
    :miq_cim_associations,             [:id, :miq_cim_instance_id, :result_instance_id],
    :miq_cim_derived_stats,            [:id, :miq_cim_stat_id],
    :miq_cim_instances,                [:id, :top_managed_element_id, :agent_top_id, :agent_id, :stat_id, :stat_top_id],
    :miq_cim_stats,                    [:id],
    :miq_enterprises,                  [:id],
    :miq_events,                       [:id],
    :miq_globals,                      [:id],
    :miq_groups,                       [:id, :ui_task_set_id, :resource_id],
    :miq_license_contents,             [:id],
    :miq_policies,                     [:id],
    :miq_policy_contents,              [:id, :miq_policy_id, :miq_action_id, :miq_event_id],
    :miq_provision_requests,           [:id, :src_vm_id],
    :miq_provisions,                   [:id, :miq_provision_request_id, :vm_id, :src_vm_id],
    :miq_proxies,                      [:id, :host_id, :vm_id],
    :miq_proxies_product_updates,      [:product_update_id, :miq_proxy_id],
    :miq_queue,                        [:id, :target_id, :instance_id, :miq_worker_id],
    :miq_report_result_details,        [:id, :miq_report_result_id],
    :miq_report_results,               [:id, :miq_report_id, :miq_task_id],
    :miq_reports,                      [:id, :time_profile_id],
    :miq_requests,                     [:id, :resource_id, :requester_id],
    :miq_schedules,                    [:id, :miq_search_id, :zone_id],
    :miq_scsi_luns,                    [:id, :miq_scsi_target_id],
    :miq_scsi_targets,                 [:id, :guest_device_id],
    :miq_searches,                     [:id],
    :miq_servers,                      [:id, :zone_id],
    :miq_servers_product_updates,      [:product_update_id, :miq_server_id],
    :miq_sets,                         [:id],
    :miq_smis_agents,                  [:id],
    :miq_tasks,                        [:id, :miq_server_id],
    :miq_workers,                      [:id, :miq_server_id],
    :networks,                         [:id, :hardware_id, :device_id],
    :operating_systems,                [:id, :vm_id, :host_id],
    :os_processes,                     [:id, :operating_system_id],
    :partitions,                       [:id, :disk_id, :hardware_id],
    :patches,                          [:id, :vm_id, :host_id],
    :policy_event_contents,            [:id, :policy_event_id, :resource_id],
    :policy_events,                    [:id, :miq_event_id, :miq_policy_id, :target_id, :chain_id, :host_id, :ems_cluster_id, :ems_id],
    :product_updates,                  [:id],
    :proxy_tasks,                      [:id, :miq_proxy_id],
    :registry_items,                   [:id, :miq_set_id, :scan_item_id, :vm_id],
    :relationships,                    [:id, :parent_id, :child_id],
    :repositories,                     [:id, :storage_id],
    :reserves,                         [:id, :resource_id],
    :resource_pools,                   [:id, :ems_id],
    :rss_feeds,                        [:id],
    :scan_histories,                   [:id, :vm_id],
    :scan_items,                       [:id],
    :server_roles,                     [:id],
    :services,                         [:id],
    :snapshots,                        [:id, :parent_id, :vm_id],
    :states,                           [:id, :resource_id],
    :storage_files,                    [:id, :storage_id, :vm_id],
    :storages,                         [:id],
    :storages_vms,                     [:storage_id, :vm_id],
    :switches,                         [:id, :host_id],
    :system_services,                  [:id, :vm_id, :host_id],
    :taggings,                         [:id, :taggable_id, :tag_id],
    :tags,                             [:id],
    :time_profiles,                    [:id],
    :ui_tasks,                         [:id],
    :users,                            [:id, :ui_task_set_id],
    :vms,                              [:id, :host_id, :storage_id, :service_id, :ems_id, :evm_owner_id],
    :volumes,                          [:id, :hardware_id],
    :zones,                            [:id]
  ]

  LARGE_TABLES = [
    :ems_events,                       [:id, :host_id, :vm_id, :dest_host_id, :dest_vm_id, :chain_id, :ems_id, :ems_cluster_id, :dest_ems_cluster_id],
    :vim_performance_states,           [:id, :resource_id],
    :vim_performance_tag_values,       [:id, :vim_performance_id],
    :vim_performances,                 [:id, :resource_id, :parent_host_id, :parent_ems_cluster_id, :parent_storage_id, :parent_ems_id],
  ]

  INDEXES = [
    [:accounts,                         [:vm_id]],
    [:authentications,                  [:resource_type, :resource_id]],
    [:binary_blob_parts,                [:binary_blob_id]],
    [:binary_blobs,                     [:resource_type, :resource_id]],
    [:classifications,                  [:parent_id]],
    [:classifications,                  [:tag_id]],
    [:disks,                            [:hardware_id]],
    [:ems_clusters,                     [:ems_id]],
    [:ems_events,                       [:ems_id, :chain_id]],
    [:ems_folders,                      [:ems_id]],
    [:filesystems,                      [:miq_set_id]],
    [:filesystems,                      [:resource_type, :resource_id]],
    [:filesystems,                      [:scan_item_id]],
    [:guest_applications,               [:vm_id]],
    [:guest_devices,                    [:hardware_id]],
    [:guest_devices,                    [:lan_id]],
    [:guest_devices,                    [:switch_id]],
    [:hosts,                            [:ems_id]],
    [:hosts_storages,                   [:host_id, :storage_id], {:unique=>true}],
    [:jobs,                             [:agent_class, :agent_id]],
    [:lans,                             [:switch_id]],
    [:lifecycle_events,                 [:vm_id]],
    [:miq_ae_fields,                    [:class_id], {:name=>"index_miq_ae_fields_on_ae_class_id"}],
    [:miq_ae_instances,                 [:class_id], {:name=>"index_miq_ae_instances_on_ae_class_id"}],
    [:miq_ae_values,                    [:field_id]],
    [:miq_ae_values,                    [:instance_id]],
    [:miq_cim_associations,             [:miq_cim_instance_id]],
    [:miq_cim_associations,             [:result_instance_id]],
    [:miq_cim_derived_stats,            [:miq_cim_stat_id]],
    [:miq_cim_instances,                [:agent_id]],
    [:miq_cim_instances,                [:agent_top_id]],
    [:miq_cim_instances,                [:stat_id]],
    [:miq_cim_instances,                [:stat_top_id]],
    [:miq_cim_instances,                [:top_managed_element_id]],
    [:miq_proxies,                      [:host_id]],
    [:miq_queue,                        [:state, :zone, :task_id, :queue_name, :role, :server_guid, :deliver_on, :priority, :id], {:name=>"miq_queue_idx"}],
    [:miq_scsi_luns,                    [:miq_scsi_target_id]],
    [:miq_scsi_targets,                 [:guest_device_id]],
    [:miq_workers,                      [:miq_server_id]],
    [:networks,                         [:device_id]],
    [:networks,                         [:hardware_id]],
    [:operating_systems,                [:host_id]],
    [:operating_systems,                [:vm_id]],
    [:partitions,                       [:disk_id]],
    [:partitions,                       [:hardware_id, :volume_group]],
    [:patches,                          [:host_id]],
    [:patches,                          [:vm_id]],
    [:proxy_tasks,                      [:miq_proxy_id]],
    [:registry_items,                   [:miq_set_id]],
    [:registry_items,                   [:scan_item_id]],
    [:registry_items,                   [:vm_id]],
    [:relationships,                    [:child_type, :child_id]],
    [:relationships,                    [:parent_type, :parent_id]],
    [:repositories,                     [:storage_id]],
    [:resource_pools,                   [:ems_id]],
    [:scan_histories,                   [:vm_id]],
    [:snapshots,                        [:parent_id]],
    [:snapshots,                        [:vm_id]],
    [:states,                           [:resource_type, :resource_id]],
    [:storages_vms,                     [:vm_id, :storage_id], {:unique=>true}],
    [:switches,                         [:host_id]],
    [:system_services,                  [:host_id]],
    [:system_services,                  [:vm_id]],
    [:taggings,                         [:tag_id]],
    [:taggings,                         [:taggable_type, :taggable_id]],
    [:users,                            [:ui_task_set_id]],
    [:vim_performance_states,           [:resource_type, :resource_id, :timestamp], {:name=>"index_vim_performance_states_on_resource_and_timestamp"}],
    [:vim_performance_tag_values,       [:vim_performance_id]],
    [:vim_performances,                 [:capture_interval_name, :resource_type, :resource_id, :timestamp], {:name=>"index_vim_performances_on_resource_and_timestamp"}],
    [:vms,                              [:ems_id]],
    [:vms,                              [:host_id]],
    [:vms,                              [:service_id]],
    [:vms,                              [:storage_id]],
    [:volumes,                          [:hardware_id, :volume_group]]
  ]

  # In 3.3.2, the following migrations with NEW indexes on id type columns were added.
  # These migrations were created AFTER this migration and included in 3.3.2.
  # Since this migration was never included in 3.3.2, these new migrations would
  # have be run and added the indexes.  Therefore, we need to remove these additional
  # indexes, if they exist, before converting the id type columns to 64 bit and then
  # re-add the index if it was removed.
  #
  # 20100818152022_add_indexes_to_ems_events.rb
  # 20100818223202_update_indexes_on_ems_events.rb
  # 20100901210737_add_index_to_miq_report_result_details.rb
  ADDITIONAL_INDEXES = [
    [:ems_events,                [:dest_host_id]],
    [:ems_events,                [:dest_vm_id]],
    [:ems_events,                [:ems_cluster_id]],
    [:ems_events,                [:ems_id]],
    [:ems_events,                [:host_id]],
    [:ems_events,                [:vm_id]],
    [:miq_report_result_details, [:miq_report_result_id, :data_type, :id], {:name => "miq_report_result_details_idx"}],
  ]

  def self.up
    drop_performances_views

    INDEXES.each do |args|
      remove_index_ex(*args) if index_exists?(*args)
    end

    additional_indexes_found = []
    ADDITIONAL_INDEXES.each do |args|
      if index_exists?(*args)
        remove_index_ex *args
        additional_indexes_found << args
      end
    end

    TABLES.each_slice(2) do |table, id_cols|
      change_id_columns table, id_cols, :bigint
    end

    LARGE_TABLES.each_slice(2) do |table, id_cols|
      change_id_columns_for_large_tables table, id_cols, :bigint
    end

    INDEXES.each do |args|
      add_index_ex *args
    end

    additional_indexes_found.each do |args|
      add_index_ex *args
    end

    create_performances_views
  end

  def self.down
    drop_performances_views

    INDEXES.each do |args|
      remove_index_ex(*args) if index_exists?(*args)
    end

    TABLES.each_slice(2) do |table, id_cols|
      change_id_columns table, id_cols, :integer
    end

    LARGE_TABLES.each_slice(2) do |table, id_cols|
      change_id_columns_for_large_tables table, id_cols, :integer
    end

    INDEXES.each do |args|
      add_index_ex *args
    end

    create_performances_views
  end

  #
  # MySQL specific methods
  #

  def self.add_index_ex(*args)
    if args[0] == :miq_queue && connection.adapter_name == "MySQL"
      # Handle issue where MySQL has a limited key size
      add_mysql_miq_queue_index
    else
      add_index *args
    end
  end

  def self.add_mysql_miq_queue_index
    say_with_time('add_index(:miq_queue, [:state (100), :zone (100), :task_id, :queue_name (100), :role (100), :server_guid, :deliver_on, :priority, :id], {:name=>"miq_queue_idx"})') do
      connection.execute("CREATE INDEX `miq_queue_idx` ON `miq_queue` (`state` (100), `zone` (100), `task_id`, `queue_name` (100), `role` (100), `server_guid`, `deliver_on`, `priority`, `id`)").to_s
    end
  end
end
