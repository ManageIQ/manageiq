class AddLocationsParent < ActiveRecord::Migration
  def change
    add_column :configuration_locations, :parent_id, :bigint
    add_column :configuration_locations, :parent_ref, :string
    add_column :configuration_organizations, :parent_id, :bigint
    add_column :configuration_organizations, :parent_ref, :string
    add_column :configuration_profiles, :parent_id, :bigint
    add_column :configuration_profiles, :parent_ref, :string
  end
end
