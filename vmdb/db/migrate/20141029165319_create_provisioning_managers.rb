class CreateProvisioningManagers < ActiveRecord::Migration
  def up
    create_table :customization_scripts do |t|
      t.string     :name
      t.belongs_to :provisioning_manager, :type => :bigint
      t.string     :manager_ref
      t.string     :type
      t.timestamps
    end
    add_index :customization_scripts, :manager_ref
    add_index :customization_scripts, [:provisioning_manager_id, :type],
              :name => :index_on_customization_script_provisioning_manager_id

    create_table :operating_system_flavors do |t|
      t.string     :name
      t.string     :description
      t.belongs_to :provisioning_manager, :type => :bigint
      t.string     :manager_ref
      t.timestamps
    end
    add_index :operating_system_flavors, :manager_ref
    add_index :operating_system_flavors, :provisioning_manager_id

    create_table :customization_scripts_operating_system_flavors, :id => false do |t|
      t.belongs_to :customization_script,    :type => :bigint
      t.belongs_to :operating_system_flavor,   :type => :bigint
    end
    add_index :customization_scripts_operating_system_flavors, [:operating_system_flavor_id, :customization_script_id],
              :name => :index_on_customization_scripts_operating_system_flavors_i1
    add_index :customization_scripts_operating_system_flavors, [:customization_script_id, :operating_system_flavor_id],
              :name => :index_on_customization_scripts_operating_system_flavors_i2

    create_table :provisioning_managers do |t|
      t.belongs_to :provider, :type => :bigint
      t.string     :type
      t.timestamps
    end
    add_index :provisioning_managers, :provider_id
  end

  def down
    drop_table :provisioning_managers
    drop_table :customization_scripts_operating_system_flavors
    drop_table :operating_system_flavors
    drop_table :customization_scripts
  end
end
