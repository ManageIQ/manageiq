class DropConfigrationManagerAndProvisioningManager < ActiveRecord::Migration
  def up
    remove_index :configuration_managers, :provider_id
    drop_table   :configuration_managers

    remove_index :provisioning_managers, :provider_id
    drop_table   :provisioning_managers
  end

  def down
    create_table :configuration_managers do |t|
      t.string   :type
      t.bigint   :provider_id
      t.datetime :created_at
      t.datetime :updated_at
      t.text     :last_refresh_error
      t.datetime :last_refresh_date
    end

    add_index :configuration_managers, :provider_id

    create_table :provisioning_managers do |t|
      t.string   :type
      t.bigint   :provider_id
      t.datetime :created_at
      t.datetime :updated_at
      t.text     :last_refresh_error
      t.datetime :last_refresh_date
    end

    add_index :provisioning_managers, :provider_id
  end
end
