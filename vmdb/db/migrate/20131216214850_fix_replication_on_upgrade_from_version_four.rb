class FixReplicationOnUpgradeFromVersionFour < ActiveRecord::Migration
  include MigrationHelper
  include MigrationHelper::SharedStubs

  class Configuration < ActiveRecord::Base
    serialize :settings
    self.inheritance_column = :_type_disabled # disable STI
  end

  V5_DEFAULT_EXCLUDE_TABLES = %w{
    assigned_server_roles
    audit_events
    binary_blobs
    binary_blob_parts
    chargeback_rate_details
    chargeback_rates
    conditions
    conditions_miq_policies
    configurations
    custom_buttons
    customization_specs
    database_backups
    event_logs
    file_depots
    jobs
    log_files
    metrics
    metrics_00
    metrics_01
    metrics_02
    metrics_03
    metrics_04
    metrics_05
    metrics_06
    metrics_07
    metrics_08
    metrics_09
    metrics_10
    metrics_11
    metrics_12
    metrics_13
    metrics_14
    metrics_15
    metrics_16
    metrics_17
    metrics_18
    metrics_19
    metrics_20
    metrics_21
    metrics_22
    metrics_23
    metric_rollups
    miq_actions
    miq_ae_classes
    miq_ae_fields
    miq_ae_instances
    miq_ae_methods
    miq_ae_namespaces
    miq_ae_values
    miq_ae_workspaces
    miq_alert_statuses
    miq_alerts
    miq_databases
    miq_enterprises
    miq_events
    miq_globals
    miq_groups
    miq_license_contents
    miq_policies
    miq_policy_contents
    miq_product_features
    miq_proxies_product_updates
    miq_proxies
    miq_queue
    miq_roles_features
    miq_report_result_details
    miq_report_results
    miq_reports
    miq_searches
    miq_servers_product_updates
    miq_sets
    miq_schedules
    miq_tasks
    miq_user_roles
    miq_widgets
    miq_widget_contents
    miq_workers
    product_updates
    proxy_tasks
    rss_feeds
    schema_migrations
    server_roles
    sessions
    ui_tasks
    vim_performances
    vim_performance_states
    vim_performance_tag_values
    vmdb_database_metrics
    vmdb_databases
    vmdb_indexes
    vmdb_metrics
    vmdb_tables
  }

  RENAMED_TABLES = {
    "states"                => "drift_states",
    "miq_cim_derived_stats" => "miq_cim_derived_metrics",
    "miq_provisions"        => "miq_request_tasks",
    "miq_cim_stats"         => "miq_storage_metrics",
    "storages_vms"          => "storages_vms_and_templates",
  }

  REMOVED_TABLES = %w{
    automation_requests
    automation_tasks
    miq_provision_requests
    vim_performances
  }

  def up
    say_with_time("Updating configurations for replication") do
      path = ["workers", "worker_base", :replication_worker, :replication]
      Configuration.where(:typ => "vmdb").each do |c|
        settings_path = path.dup.push(:include_tables)
        Rails.logger.info("Removing the path [#{settings_path.join(", ")}] from Configuration id [#{c.id}].")
        Rails.logger.info("Current value is:\n#{c.settings.fetch_path(settings_path).to_yaml}")
        c.settings.delete_path(settings_path)

        settings_path = path.dup.push(:exclude_tables)
        Rails.logger.info("Replacing the path [#{settings_path.join(", ")}] from Configuration id [#{c.id}].")
        Rails.logger.info("Current value is:\n#{c.settings.fetch_path(settings_path).to_yaml}")
        c.settings.store_path(settings_path, V5_DEFAULT_EXCLUDE_TABLES)

        c.save!
      end
    end

    if RrSyncState.table_exists?
      prefix = "rr#{ActiveRecord::Base.my_region_number}"
      RENAMED_TABLES.each do |old_name, new_name|
        drop_trigger(new_name, "#{prefix}_#{old_name}")
      end

      say_with_time("Updating #{RrPendingChange.table_name} for renamed tables") do
        RENAMED_TABLES.each do |old_name, new_name|
          RrPendingChange.where(:change_table => old_name).update_all(:change_table => new_name)
        end
      end

      say_with_time("Updating #{RrSyncState.table_name} for renamed tables") do
        RENAMED_TABLES.each do |old_name, new_name|
          RrSyncState.where(:table_name => old_name).update_all(:table_name => new_name)
        end
      end

      say_with_time("Updating #{RrSyncState.table_name} for removed tables") do
        RrSyncState.where(:table_name => REMOVED_TABLES).delete_all
      end

      require 'awesome_spawn'

      say_with_time("Preparing rubyrep") do
        AwesomeSpawn.run!("bin/rake evm:dbsync:prepare_replication_without_sync")
      end

      say_with_time("Uninstalling rubyrep for renamed tables") do
        AwesomeSpawn.run!("bin/rake evm:dbsync:uninstall #{RENAMED_TABLES.values.join(" ")}")
      end
    end
  end
end
