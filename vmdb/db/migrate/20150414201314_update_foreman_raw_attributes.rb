class UpdateForemanRawAttributes < ActiveRecord::Migration
  def change
    rename_column :configured_systems, :operating_system_flavor_id,     :raw_operating_system_flavor_id
    rename_column :configured_systems, :customization_script_medium_id, :raw_customization_script_medium_id
    rename_column :configured_systems, :customization_script_ptable_id, :raw_customization_script_ptable_id

    rename_column :configuration_profiles, :operating_system_flavor_id,     :raw_operating_system_flavor_id
    rename_column :configuration_profiles, :customization_script_medium_id, :raw_customization_script_medium_id
    rename_column :configuration_profiles, :customization_script_ptable_id, :raw_customization_script_ptable_id
  end
end
