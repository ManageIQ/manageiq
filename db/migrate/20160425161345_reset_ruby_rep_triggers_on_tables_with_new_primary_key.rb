class ResetRubyRepTriggersOnTablesWithNewPrimaryKey < ActiveRecord::Migration[5.0]
  include MigrationHelper
  include MigrationHelper::SharedStubs

  TABLES = %w(
    cloud_tenants_vms
    conditions_miq_policies
    configuration_locations_configuration_profiles
    configuration_organizations_configuration_profiles
    configuration_profiles_configuration_tags
    configuration_tags_configured_systems
    container_groups_container_services
    customization_scripts_operating_system_flavors
    direct_configuration_profiles_configuration_tags
    direct_configuration_tags_configured_systems
    key_pairs_vms
    miq_groups_users
    miq_roles_features
    miq_servers_product_updates
    network_ports_security_groups
    security_groups_vms
    storages_vms_and_templates
  ).freeze

  def up
    return unless RrSyncState.table_exists?

    TABLES.each do |t|
      drop_trigger(t, "rr#{ApplicationRecord.my_region_number}_#{t}")
      RrPendingChange.where(:change_table => t).delete_all
      RrSyncState.where(:table_name => t).delete_all
    end
  end
end
