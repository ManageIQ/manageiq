class UpdateForemanRawAttributes < ActiveRecord::Migration
  def change
    rename_column :configured_systems, :operating_system_flavor_id,     :direct_operating_system_flavor_id
    rename_column :configured_systems, :customization_script_medium_id, :direct_customization_script_medium_id
    rename_column :configured_systems, :customization_script_ptable_id, :direct_customization_script_ptable_id

    remove_index :configuration_profiles, :column => :operating_system_flavor_id, :name => 'index_configuration_profiles_on_operating_system_flavor_id'
    remove_index :configuration_profiles, :column => :customization_script_medium_id, :name => 'index_configuration_profiles_on_customization_script_medium_id'
    remove_index :configuration_profiles, :column => :customization_script_ptable_id, :name => 'index_configuration_profiles_on_customization_script_ptable_id'

    rename_column :configuration_profiles, :operating_system_flavor_id,     :direct_operating_system_flavor_id
    rename_column :configuration_profiles, :customization_script_medium_id, :direct_customization_script_medium_id
    rename_column :configuration_profiles, :customization_script_ptable_id, :direct_customization_script_ptable_id

    add_index :configuration_profiles, [:direct_operating_system_flavor_id], :name => 'index_configuration_profiles_on_operating_system_flavor_id'
    add_index :configuration_profiles, [:direct_customization_script_medium_id], :name => 'index_configuration_profiles_on_customization_script_medium_id'
    add_index :configuration_profiles, [:direct_customization_script_ptable_id], :name => 'index_configuration_profiles_on_customization_script_ptable_id'
  end
end
