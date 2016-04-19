class AddIdPrimaryKeyToJoinTables < ActiveRecord::Migration[5.0]
  JOIN_TABLES = %w(
    conditions_miq_policies
    key_pairs_vms
    miq_roles_features
    security_groups_vms
    storages_vms_and_templates
    miq_groups_users
    cloud_tenants_vms
    customization_scripts_operating_system_flavors
    configuration_locations_configuration_profiles
    configuration_organizations_configuration_profiles
    configuration_profiles_configuration_tags
    configuration_tags_configured_systems
    container_groups_container_services
    direct_configuration_profiles_configuration_tags
    direct_configuration_tags_configured_systems
    network_ports_security_groups
  ).freeze

  COMPOSITE_KEY_MAP = {
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
    "network_ports_security_groups"                      => "network_port_id, security_group_id",
    "security_groups_vms"                                => "security_group_id, vm_id",
    "storages_vms_and_templates"                         => "storage_id, vm_or_template_id"
  }.freeze

  class MiqRegion < ActiveRecord::Base; end

  def up
    say_with_time("Removing composite primary keys from join tables") do
      COMPOSITE_KEY_MAP.keys.each do |table|
        execute("ALTER TABLE #{table} DROP CONSTRAINT #{table}_pkey")
      end
    end

    JOIN_TABLES.each do |t|
      delete_remote_region_rows(t) if on_replication_target?

      say_with_time("Add primary key \"id\" to #{t}") do
        execute <<-SQL
          CREATE SEQUENCE #{sequence_name(t)} START #{seq_start_value}
        SQL

        execute <<-SQL
          ALTER TABLE #{t} ADD COLUMN id BIGINT PRIMARY KEY
          DEFAULT NEXTVAL('#{sequence_name(t)}')
        SQL

        execute <<-SQL
          ALTER SEQUENCE #{sequence_name(t)} OWNED BY #{t}.id
        SQL
      end
    end
  end

  def down
    JOIN_TABLES.each do |t|
      remove_column t.to_sym, :id
    end

    COMPOSITE_KEY_MAP.each do |table, key|
      execute("ALTER TABLE #{table} ADD PRIMARY KEY (#{key})")
    end
  end

  def delete_remote_region_rows(table)
    model = Class.new(ApplicationRecord) { self.table_name = table }
    col = model.column_names_symbols.first
    model.where.not(col => model.region_to_range(model.my_region_number)).delete_all
  end

  def on_replication_target?
    MiqRegion.select(:region).distinct.count > 1
  end

  def sequence_name(table)
    "#{table}_id_seq"
  end

  def seq_start_value
    val = ApplicationRecord.rails_sequence_start
    val == 0 ? 1 : val
  end
end
