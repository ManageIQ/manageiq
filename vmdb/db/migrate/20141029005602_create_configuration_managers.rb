class CreateConfigurationManagers < ActiveRecord::Migration
  def up
    create_table :configuration_managers do |t|
      t.belongs_to :provider, :type => :bigint
      t.string     :type
      t.timestamps
    end
    add_index :configuration_managers, :provider_id

    create_table :configuration_profiles do |t|
      t.string     :type
      t.string     :name
      t.string     :description
      t.belongs_to :operating_system_flavor, :type => :bigint
      t.belongs_to :configuration_manager,   :type => :bigint
      t.string     :manager_ref
      t.timestamps
    end

    add_index :configuration_profiles, :operating_system_flavor_id
    add_index :configuration_profiles, :configuration_manager_id

    add_index :configuration_profiles, :manager_ref

    create_table :configuration_profiles_customization_scripts, :id => false do |t|
      t.belongs_to :configuration_profile,   :type => :bigint
      t.belongs_to :customization_script,    :type => :bigint
    end
    add_index :configuration_profiles_customization_scripts, [:configuration_profile_id, :customization_script_id],
              :name => :index_on_configuration_profiles_customization_scripts_i1
    add_index :configuration_profiles_customization_scripts, [:customization_script_id, :configuration_profile_id],
              :name => :index_on_configuration_profiles_customization_scripts_i2

    create_table :configured_systems do |t|
      t.string     :hostname
      t.belongs_to :operating_system_flavor, :type => :bigint
      t.belongs_to :configuration_profile,   :type => :bigint
      t.belongs_to :configuration_manager,   :type => :bigint
      t.string     :manager_ref
      t.string     :type
      t.timestamps
    end
    add_index :configured_systems, :operating_system_flavor_id
    add_index :configured_systems, [:configuration_manager_id, :type]
    add_index :configured_systems, :manager_ref

    create_table :configured_systems_customization_scripts, :id => false do |t|
      t.belongs_to :configured_system,   :type => :bigint
      t.belongs_to :customization_script,    :type => :bigint
    end
    add_index :configured_systems_customization_scripts, [:configured_system_id, :customization_script_id],
              :name => :index_on_configured_systems_customization_scripts_i1
    add_index :configured_systems_customization_scripts, [:customization_script_id, :configured_system_id],
              :name => :index_on_configured_systems_customization_scripts_i2

    create_table :providers do |t|
      t.string  :name
      t.string  :url
      t.integer :verify_ssl
      t.string  :type
      t.string  :guid, :limit => 36
      t.belongs_to :zone, :type => :bigint
      t.timestamps
    end
  end

  def down
    drop_table :providers
    drop_table :configured_systems_customization_scripts
    drop_table :configured_systems
    drop_table :configuration_profiles_customization_scripts
    drop_table :configuration_profiles
    drop_table :configuration_managers
  end
end
