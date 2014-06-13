require Rails.root.join('lib/migration_helper')

class CreateIndicesForImplicitForeignKeys < ActiveRecord::Migration
  include MigrationHelper

  INDEXES = [
    [:accounts, :host_id],
    [:advanced_settings, [:resource_id, :resource_type]],
    [:assigned_server_roles, :miq_server_id],
    [:assigned_server_roles, :server_role_id],
    [:audit_events, [:target_id, :target_class]],
    [:bottleneck_events, [:resource_id, :resource_type]],
    [:chargeback_rate_details, :chargeback_rate_id],
    [:compliance_details, :compliance_id],
    [:compliance_details, :miq_policy_id],
    [:compliance_details, :condition_id],
    [:conditions, :miq_policy_id],
    [:configurations, :miq_server_id],
    [:custom_attributes, [:resource_id, :resource_type]],
    [:customization_specs, :ems_id],
    [:disks, :storage_id],
    [:event_logs, :event_id],
    [:event_logs, :operating_system_id],
    [:firewall_rules, :operating_system_id],
    [:guest_applications, :host_id],
    [:hardwares, :host_id],
    [:hardwares, :vm_id],
    [:jobs, [:target_id, :target_class]],
    [:jobs, :miq_server_id],
    [:log_files, [:resource_id, :resource_type]],
    [:log_files, :miq_task_id],
    [:miq_ae_classes, :namespace_id],
    [:miq_ae_classes, :updated_by_user_id],
    [:miq_ae_fields, :method_id],
    [:miq_ae_fields, :updated_by_user_id],
    [:miq_ae_instances, :updated_by_user_id],
    [:miq_ae_methods, :class_id],
    [:miq_ae_methods, :updated_by_user_id],
    [:miq_ae_namespaces, :parent_id],
    [:miq_ae_namespaces, :updated_by_user_id],
    [:miq_ae_values, :updated_by_user_id],
    [:miq_alert_statuses, [:resource_id, :resource_type]],
    [:miq_alert_statuses, :miq_alert_id],
    [:miq_approvals, [:approver_id, :approver_type]],
    [:miq_approvals, :miq_request_id],
    [:miq_approvals, :stamper_id],
    [:miq_groups, [:resource_id, :resource_type]],
    [:miq_groups, :miq_user_role_id],
    [:miq_groups, :ui_task_set_id],
    [:miq_policy_contents, :miq_action_id],
    [:miq_policy_contents, :miq_event_id],
    [:miq_policy_contents, :miq_policy_id],
    [:miq_product_features, :parent_id],
    [:miq_proxies, :vm_id],
    [:miq_proxies, :vdi_farm_id],
    [:miq_report_results, :miq_group_id],
    [:miq_report_results, :miq_report_id],
    [:miq_report_results, :miq_task_id],
    [:miq_reports, :miq_group_id],
    [:miq_reports, :time_profile_id],
    [:miq_request_tasks, :miq_request_id],
    [:miq_request_tasks, [:source_id, :source_type]],
    [:miq_request_tasks, [:destination_id, :destination_type]],
    [:miq_requests, :requester_id],
    [:miq_requests, [:source_id, :source_type]],
    [:miq_requests, [:destination_id, :destination_type]],
    [:miq_schedules, :miq_search_id],
    [:miq_schedules, :zone_id],
    [:miq_servers, :vm_id],
    [:miq_servers, :zone_id],
    [:miq_sets, [:owner_id, :owner_type]],
    [:miq_tasks, :miq_server_id],
    [:miq_widget_contents, :miq_report_result_id],
    [:miq_widget_contents, :miq_widget_id],
    [:miq_widget_contents, :user_id],
    [:miq_widgets, [:resource_id, :resource_type]],
    [:miq_widgets, :miq_schedule_id],
    [:miq_widgets, :miq_task_id],
    [:os_processes, :operating_system_id],
    [:policy_event_contents, [:resource_id, :resource_type]],
    [:policy_event_contents, :policy_event_id],
    [:policy_events, [:target_id, :target_class]],
    [:policy_events, :chain_id],
    [:policy_events, :ems_id],
    [:policy_events, :ems_cluster_id],
    [:policy_events, :host_id],
    [:policy_events, :miq_event_id],
    [:policy_events, :miq_policy_id],
    [:pxe_images, :pxe_server_id],
    [:reserves, [:resource_id, :resource_type]],
    [:storage_files, :storage_id],
    [:storage_files, :vm_id],
    [:storage_managers, :zone_id],
    [:storage_managers, :parent_agent_id],
    [:users, :miq_group_id],
    [:vdi_controllers, :vdi_farm_id],
    [:vdi_desktop_pools, :ems_id],
    [:vdi_desktop_pools, :vdi_farm_id],
    [:vdi_desktops, :vm_id],
    [:vdi_desktops, :vdi_desktop_pool_id],
    [:vdi_desktops, :vdi_user_id],
    [:vdi_sessions, :vdi_controller_id],
    [:vdi_sessions, :vdi_desktop_id],
    [:vdi_sessions, :vdi_endpoint_device_id],
    [:vdi_sessions, :vdi_user_id],
    [:vim_performance_operating_ranges, [:resource_id, :resource_type], {:name => 'index_vpor_on_resource'} ],
    [:vim_performance_operating_ranges, :time_profile_id,               {:name => 'index_vpor_on_time_profile_id'} ],
    [:vms, :evm_owner_id],
    [:vms, :miq_group_id],
  ]

  def up
    INDEXES.each do |table, column, options|
      if options.kind_of?(Hash)
        next if index_exists?(table, column, options)
        add_index table, column, options
      else
        next if index_exists?(table, column)
        add_index table, column
      end
    end
  end

  def down
    INDEXES.each do |table, column, options|
      options ||= {}
      if options[:name]
        remove_index(table, :name => options[:name]) rescue nil
      else
        remove_index(table, column) rescue nil
      end
    end
  end
end
