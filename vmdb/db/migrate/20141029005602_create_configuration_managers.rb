class CreateConfigurationManagers < ActiveRecord::Migration
  def up
    create_table :configuration_managers do |t|
      t.belongs_to :provider, :type => :bigint
      t.string     :type
      t.timestamps
    end
    add_index :configuration_managers, :provider_id

    create_table :configuration_profiles do |t|
      t.string     :name
      t.belongs_to :operating_system_flavor, :type => :bigint
      t.belongs_to :provider,                :type => :bigint
      t.belongs_to :configuration_manager,   :type => :bigint
      t.string     :provider_ref
      t.timestamps
    end
    add_index :configuration_profiles, :operating_system_flavor_id
    add_index :configuration_profiles, :provider_id
    add_index :configuration_profiles, :provider_ref

    create_table :configured_systems do |t|
      t.string     :hostname
      t.belongs_to :operating_system_flavor, :type => :bigint
      t.belongs_to :provider,                :type => :bigint
      t.belongs_to :configuration_manager,   :type => :bigint
      t.string     :provider_ref
      t.string     :type
      t.timestamps
    end
    add_index :configured_systems, :operating_system_flavor_id
    add_index :configured_systems, :provider_id
    add_index :configured_systems, :provider_ref

    create_table :providers do |t|
      t.string  :name
      t.string  :hostname
      t.integer :port
      t.integer :verify_ssl
      t.string  :type
      t.string  :guid, :limit => 36
      t.timestamps
    end
  end

  def down
    drop_table :providers
    drop_table :configured_systems
    drop_table :configuration_profiles
    drop_table :configuration_managers
  end
end
