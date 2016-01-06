class AddCompositePrimaryKeysToJoinTables < ActiveRecord::Migration
  TABLE_MAP = {
    "cloud_tenants_vms"                                  => "cloud_tenant_id, vm_id",
    "conditions_miq_policies"                            => "miq_policy_id, condition_id",
    "configuration_locations_configuration_profiles"     => "configuration_location_id, configuration_profile_id",
    "configuration_organizations_configuration_profiles" => "configuration_organization_id, configuration_profile_id",
    "configuration_profiles_configuration_tags"          => "configuration_profile_id, configuration_tag_id",
    "configuration_tags_configured_systems"              => "configured_system_id, configuration_tag_id",
    "container_groups_container_services"                => "container_service_id, container_group_id",
    "customization_scripts_operating_system_flavors"     => "customization_script_id, operating_system_flavor_id",
    "direct_configuration_profiles_configuration_tags"   => "configuration_profile_id, configuration_tag_id",
    "direct_configuration_tags_configured_systems"       => "configured_system_id, configuration_tag_id",
    "key_pairs_vms"                                      => "authentication_id, vm_id",
    "miq_groups_users"                                   => "miq_group_id, user_id",
    "miq_roles_features"                                 => "miq_user_role_id, miq_product_feature_id",
    "miq_servers_product_updates"                        => "product_update_id, miq_server_id",
    "network_ports_security_groups"                      => "network_port_id, security_group_id",
    "security_groups_vms"                                => "security_group_id, vm_id",
    "storages_vms_and_templates"                         => "storage_id, vm_or_template_id"
  }.freeze

  def up
    TABLE_MAP.each do |table, key|
      execute("ALTER TABLE #{table} ADD PRIMARY KEY (#{key})")
    end
  end

  def down
    TABLE_MAP.keys.each do |table|
      execute("ALTER TABLE #{table} DROP CONSTRAINT #{table}_pkey")
    end
  end
end
