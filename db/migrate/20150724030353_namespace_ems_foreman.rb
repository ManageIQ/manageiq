class NamespaceEmsForeman < ActiveRecord::Migration
  NAME_MAP = Hash[*%w(
    ConfigurationManager                        ManageIQ::Providers::ConfigurationManager
    ProvisioningManager                         ManageIQ::Providers::ProvisioningManager

    ProviderForeman                             ManageIQ::Providers::Foreman::Provider
    ConfigurationManagerForeman                 ManageIQ::Providers::Foreman::ConfigurationManager
    ConfigurationProfileForeman                 ManageIQ::Providers::Foreman::ConfigurationManager::ConfigurationProfile
    ConfiguredSystemForeman                     ManageIQ::Providers::Foreman::ConfigurationManager::ConfiguredSystem
    MiqProvisionConfiguredSystemForemanWorkflow ManageIQ::Providers::Foreman::ConfigurationManager::ProvisionWorkflow
    MiqProvisionTaskConfiguredSystemForeman     ManageIQ::Providers::Foreman::ConfigurationManager::ProvisionTask
    ProvisioningManagerForeman                  ManageIQ::Providers::Foreman::ProvisioningManager
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
