class CreateConfigurationManagers < ActiveRecord::Migration
  def up
    create_table :configuration_managers do |t|
      t.string     :type
      t.belongs_to :provider, :type => :bigint
      t.timestamps
    end
    add_index :configuration_managers, :provider_id

    create_table :configuration_profiles do |t|
      t.string     :type
      t.string     :name
      t.string     :description
      t.belongs_to :operating_system_flavor,     :type => :bigint
      t.belongs_to :configuration_manager,       :type => :bigint
      t.belongs_to :customization_script_ptable, :type => :bigint
      t.belongs_to :customization_script_medium, :type => :bigint
      t.string     :manager_ref
      t.timestamps
    end

    add_index :configuration_profiles, :operating_system_flavor_id
    add_index :configuration_profiles, :configuration_manager_id
    add_index :configuration_profiles, :customization_script_ptable_id
    add_index :configuration_profiles, :customization_script_medium_id
    add_index :configuration_profiles, :manager_ref

    create_table :configured_systems do |t|
      t.string     :type
      t.string     :hostname
      t.belongs_to :operating_system_flavor, :type => :bigint
      t.belongs_to :configuration_profile,   :type => :bigint
      t.belongs_to :configuration_manager,   :type => :bigint
      t.string     :manager_ref
      t.timestamps
    end
    add_index :configured_systems, :operating_system_flavor_id
    add_index :configured_systems, [:configuration_manager_id, :type]
    add_index :configured_systems, :manager_ref
  end

  def down
    drop_table :configured_systems
    drop_table :configuration_profiles
    drop_table :configuration_managers
  end
end
