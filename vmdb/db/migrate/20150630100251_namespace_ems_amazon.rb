class NamespaceEmsAmazon < ActiveRecord::Migration
  NAME_MAP = Hash[*%w(
    AuthKeyPairCloud                           ManageIQ::Providers::CloudManager::AuthKeyPair

    EmsAmazon                                  ManageIQ::Providers::Amazon::CloudManager
    AvailabilityZoneAmazon                     ManageIQ::Providers::Amazon::CloudManager::AvailabilityZone
    CloudVolumeAmazon                          ManageIQ::Providers::Amazon::CloudManager::CloudVolume
    CloudVolumeSnapshotAmazon                  ManageIQ::Providers::Amazon::CloudManager::CloudVolumeSnapshot
    MiqEventCatcherAmazon                      ManageIQ::Providers::Amazon::CloudManager::EventCatcher
    EventCatcherAmazon                         ManageIQ::Providers::Amazon::CloudManager::EventCatcher::Runner
    FlavorAmazon                               ManageIQ::Providers::Amazon::CloudManager::Flavor
    FloatingIpAmazon                           ManageIQ::Providers::Amazon::CloudManager::FloatingIp
    MiqEmsMetricsCollectorWorkerAmazon         ManageIQ::Providers::Amazon::CloudManager::MetricsCollectorWorker
    EmsMetricsCollectorWorkerAmazon            ManageIQ::Providers::Amazon::CloudManager::MetricsCollectorWorker::Runner
    OrchestrationStackAmazon                   ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack
    MiqEmsRefreshWorkerAmazon                  ManageIQ::Providers::Amazon::CloudManager::RefreshWorker
    EmsRefreshWorkerAmazon                     ManageIQ::Providers::Amazon::CloudManager::RefreshWorker::Runner
    SecurityGroupAmazon                        ManageIQ::Providers::Amazon::CloudManager::SecurityGroup
    TemplateAmazon                             ManageIQ::Providers::Amazon::CloudManager::Template
    VmAmazon                                   ManageIQ::Providers::Amazon::CloudManager::Vm

    ServiceOrchestration::OptionConverterAmazon
                                          ManageIQ::Providers::Amazon::CloudManager::OrchestrationServiceOptionConverter
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
