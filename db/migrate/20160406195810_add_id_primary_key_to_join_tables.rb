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

  class MiqRegion < ActiveRecord::Base; end

  def up
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
  end

  def delete_remote_region_rows(table)
    model = Class.new(ActiveRecord::Base) { self.table_name = table }
    col = model.column_names_symbols.first
    ar_region_class = ArRegion.anonymous_class_with_ar_region
    model.where.not(col => ar_region_class.region_to_range(ar_region_class.my_region_number)).delete_all
  end

  def on_replication_target?
    MiqRegion.select(:region).distinct.count > 1
  end

  def sequence_name(table)
    "#{table}_id_seq"
  end

  def seq_start_value
    val = ArRegion.anonymous_class_with_ar_region.rails_sequence_start
    val == 0 ? 1 : val
  end
end
