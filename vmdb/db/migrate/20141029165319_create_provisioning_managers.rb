class CreateProvisioningManagers < ActiveRecord::Migration
  def up
    create_table :customization_scripts do |t|
      t.string     :name
      t.belongs_to :provider, :type => :bigint
      t.belongs_to :provisioning_manager, :type => :bigint
      t.string     :provider_ref
      t.string     :type
      t.timestamps
    end
    add_index :customization_scripts, :provider_id
    add_index :customization_scripts, :provider_ref

    create_table :operating_system_flavors do |t|
      t.string     :name
      t.string     :description
      t.belongs_to :provider, :type => :bigint
      t.belongs_to :provisioning_manager, :type => :bigint
      t.string     :provider_ref
      t.timestamps
    end
    add_index :operating_system_flavors, :provider_id
    add_index :operating_system_flavors, :provider_ref

    create_table :customization_scripts_operating_systems, :id => false do |t|
      t.belongs_to :customization_script,    :type => :bigint
      t.belongs_to :operating_system_flavor,   :type => :bigint
    end
    add_index :customization_scripts_operating_systems, [:operating_system_flavor_id, :customization_script_id],
              :name => :customization_scripts_operating_systems_i1
    add_index :customization_scripts_operating_systems, [:customization_script_id, :operating_system_flavor_id],
              :name => :customization_scripts_operating_systems_i2

    create_table :provision_managers do |t|
      t.belongs_to :provider, :type => :bigint
      t.string     :type
      t.timestamps
    end
    add_index :provision_managers, :provider_id
  end

  def down
    drop_table :provision_managers
    drop_table :customization_scripts_operating_systems
    drop_table :operating_system_flavors
    drop_table :customization_scripts
  end
end
