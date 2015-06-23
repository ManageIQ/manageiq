class UpdateForemanDerivedValues < ActiveRecord::Migration
  def change
    add_column :configured_systems, :operating_system_flavor_id,     :bigint
    add_column :configured_systems, :customization_script_medium_id, :bigint
    add_column :configured_systems, :customization_script_ptable_id, :bigint

    add_column :configuration_profiles, :operating_system_flavor_id,     :bigint
    add_column :configuration_profiles, :customization_script_medium_id, :bigint
    add_column :configuration_profiles, :customization_script_ptable_id, :bigint
  end
end
