class NamespaceEmsRedhat < ActiveRecord::Migration
  NAME_MAP = Hash[*%w(
    EmsRedhat                                  ManageIQ::Providers::Redhat::CloudManager
    AvailabilityZoneRedhat                     ManageIQ::Providers::Redhat::CloudManager::AvailabilityZone
    CloudVolumeRedhat                          ManageIQ::Providers::Redhat::CloudManager::CloudVolume
    CloudVolumeSnapshotRedhat                  ManageIQ::Providers::Redhat::CloudManager::CloudVolumeSnapshot
    MiqEventCatcherRedhat                      ManageIQ::Providers::Redhat::CloudManager::EventCatcher
    EventCatcherRedhat                         ManageIQ::Providers::Redhat::CloudManager::EventCatcher::Runner
    FlavorRedhat                               ManageIQ::Providers::Redhat::CloudManager::Flavor
    FloatingIpRedhat                           ManageIQ::Providers::Redhat::CloudManager::FloatingIp
    MiqEmsMetricsCollectorWorkerRedhat         ManageIQ::Providers::Redhat::CloudManager::MetricsCollectorWorker
    EmsMetricsCollectorWorkerRedhat            ManageIQ::Providers::Redhat::CloudManager::MetricsCollectorWorker::Runner
    OrchestrationStackRedhat                   ManageIQ::Providers::Redhat::CloudManager::OrchestrationStack
    MiqEmsRefreshWorkerRedhat                  ManageIQ::Providers::Redhat::CloudManager::RefreshWorker
    EmsRefreshWorkerRedhat                     ManageIQ::Providers::Redhat::CloudManager::RefreshWorker::Runner
    SecurityGroupRedhat                        ManageIQ::Providers::Redhat::CloudManager::SecurityGroup
    TemplateRedhat                             ManageIQ::Providers::Redhat::CloudManager::Template
    VmRedhat                                   ManageIQ::Providers::Redhat::CloudManager::Vm
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
