class NamespaceEmsClasses < ActiveRecord::Migration
  NAME_MAP = Hash[*%w(
    EmsCloud                               ManageIQ::Providers::CloudManager
    HostCloud                              ManageIQ::Providers::CloudManager::Host
    TemplateCloud                          ManageIQ::Providers::CloudManager::Template
    VmCloud                                ManageIQ::Providers::CloudManager::Vm

    EmsInfra                               ManageIQ::Providers::InfraManager
    HostInfra                              ManageIQ::Providers::InfraManager::Host
    TemplateInfra                          ManageIQ::Providers::InfraManager::Template
    VmInfra                                ManageIQ::Providers::InfraManager::Vm

    EmsVmware                              ManageIQ::Providers::Vmware::InfraManager
    MiqEventCatcherVmware                  ManageIQ::Providers::Vmware::InfraManager::EventCatcher
    EventCatcherVmware                     ManageIQ::Providers::Vmware::InfraManager::EventCatcher::Runner
    HostVmware                             ManageIQ::Providers::Vmware::InfraManager::Host
    HostVmwareEsx                          ManageIQ::Providers::Vmware::InfraManager::HostEsx
    MiqEmsMetricsCollectorWorkerVmware     ManageIQ::Providers::Vmware::InfraManager::MetricsCollectorWorker
    EmsMetricsCollectorWorkerVmware        ManageIQ::Providers::Vmware::InfraManager::MetricsCollectorWorker::Runner
    MiqEmsRefreshWorkerVmware              ManageIQ::Providers::Vmware::InfraManager::RefreshWorker
    EmsRefreshWorkerVmware                 ManageIQ::Providers::Vmware::InfraManager::RefreshWorker::Runner
    TemplateVmware                         ManageIQ::Providers::Vmware::InfraManager::Template
    VmVmware                               ManageIQ::Providers::Vmware::InfraManager::Vm
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
