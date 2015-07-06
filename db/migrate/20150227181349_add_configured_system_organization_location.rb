class AddConfiguredSystemOrganizationLocation < ActiveRecord::Migration
  def change
    create_table :configuration_organizations do |t|
      t.string     :type
      t.string     :name
      t.belongs_to :provisioning_manager, :type => :bigint
      t.string     :manager_ref
      t.timestamps :null => true
    end
    add_index :configuration_organizations, :provisioning_manager_id
    add_index :configuration_organizations, :manager_ref

    create_table :configuration_locations do |t|
      t.string     :type
      t.string     :name
      t.belongs_to :provisioning_manager, :type => :bigint
      t.string     :manager_ref
      t.timestamps :null => true
    end
    add_index :configuration_locations, :provisioning_manager_id
    add_index :configuration_locations, :manager_ref

    add_column :configured_systems, :configuration_location_id,      :bigint
    add_column :configured_systems, :configuration_organization_id,  :bigint

    create_table :configuration_locations_configuration_profiles, :id => false do |t|
      t.belongs_to :configuration_location, :type => :bigint
      t.belongs_to :configuration_profile,  :type => :bigint
    end
    add_index :configuration_locations_configuration_profiles, :configuration_location_id,
              :name => :index_configuration_locations_configuration_profiles_location
    add_index :configuration_locations_configuration_profiles, :configuration_profile_id,
              :name => :index_configuration_locations_configuration_profiles_profile

    create_table :configuration_organizations_configuration_profiles, :id => false do |t|
      t.belongs_to :configuration_organization, :type => :bigint
      t.belongs_to :configuration_profile,      :type => :bigint
    end
    add_index :configuration_organizations_configuration_profiles, :configuration_organization_id,
              :name => :index_configuration_organizations_configuration_profiles_org
    add_index :configuration_organizations_configuration_profiles, :configuration_profile_id,
              :name => :index_configuration_organizations_configuration_profiles_p
  end
end
