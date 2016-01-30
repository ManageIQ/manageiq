class FixRedhatNamespace < ActiveRecord::Migration
  NAME_MAP = Hash[*%w(
    ManageIQ::Providers::Redhat::CloudManager
    ManageIQ::Providers::Redhat::InfraManager
    ManageIQ::Providers::Redhat::CloudManager::EventCatcher
    ManageIQ::Providers::Redhat::InfraManager::EventCatcher
    ManageIQ::Providers::Redhat::CloudManager::EventCatcher::Runner
    ManageIQ::Providers::Redhat::InfraManager::EventCatcher::Runner
    ManageIQ::Providers::Redhat::CloudManager::MetricsCollectorWorker
    ManageIQ::Providers::Redhat::InfraManager::MetricsCollectorWorker
    ManageIQ::Providers::Redhat::CloudManager::MetricsCollectorWorker::Runner
    ManageIQ::Providers::Redhat::InfraManager::MetricsCollectorWorker::Runner
    ManageIQ::Providers::Redhat::CloudManager::RefreshWorker
    ManageIQ::Providers::Redhat::InfraManager::RefreshWorker
    ManageIQ::Providers::Redhat::CloudManager::RefreshWorker::Runner
    ManageIQ::Providers::Redhat::InfraManager::RefreshWorker::Runner
    ManageIQ::Providers::Redhat::CloudManager::Template
    ManageIQ::Providers::Redhat::InfraManager::Template
    ManageIQ::Providers::Redhat::CloudManager::Vm
    ManageIQ::Providers::Redhat::InfraManager::Vm

    HostRedhat                             ManageIQ::Providers::Redhat::InfraManager::Host
  )]

  STI_TABLES = %w(
    authentications
    availability_zones
    cloud_resource_quotas
    cloud_tenants
    cloud_volume_snapshots
    cloud_volumes
    customization_templates
    dialog_fields
    ext_management_systems
    file_depots
    flavors
    floating_ips
    hosts
    jobs
    miq_ae_classes
    miq_cim_instances
    miq_request_tasks
    miq_requests
    miq_storage_metrics
    miq_workers
    orchestration_stacks
    orchestration_templates
    pxe_images
    pxe_menus
    security_groups
    service_templates
    services
    storage_managers
    storage_metrics_metadata
    vmdb_tables
    vms
  )

  def remap(mapping)
    condition_list = mapping.keys.map { |s| connection.quote(s) }.join(',')
    case_expr = "CASE type " + mapping.map { |before, after| "WHEN #{connection.quote before} THEN #{connection.quote after}" }.join(' ') + " END"

    STI_TABLES.each do |table|
      execute "UPDATE #{table} SET type = #{case_expr} WHERE type IN (#{condition_list})"
    end
  end

  def up
    remap(NAME_MAP)
  end

  def down
    remap(NAME_MAP.invert)
  end
end
