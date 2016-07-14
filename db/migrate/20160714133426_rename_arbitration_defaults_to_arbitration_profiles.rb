class RenameArbitrationDefaultsToArbitrationProfiles < ActiveRecord::Migration[5.0]
  def up
    rename_table :arbitration_defaults, :arbitration_profiles
    add_column :arbitration_profiles, :name, :string
    add_column :arbitration_profiles, :description, :text
    add_column :arbitration_profiles, :default_profile, :boolean
  end

  def down
    rename_table :arbitration_profiles, :arbitration_defaults
    remove_column :arbitration_defaults, :name
    remove_column :arbitration_defaults, :description
    remove_column :arbitration_defaults, :default_profile
  end
end
