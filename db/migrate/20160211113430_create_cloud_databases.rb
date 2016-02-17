class CreateCloudDatabases < ActiveRecord::Migration
  def change
    create_table :cloud_database_flavors do |t|
      t.string  :name
      t.string  :type
      t.string  :ems_ref
      t.integer :cpus
      t.bigint  :memory
      t.bigint  :max_size
      t.integer :max_connections
      t.string  :performance
      t.boolean :enabled

      t.belongs_to :ems, :type => :bigint
    end

    add_index :cloud_database_flavors, :ems_id

    create_table :cloud_databases do |t|
      t.string :name
      t.string :type
      t.string :ems_ref
      t.string :db_engine
      t.string :status
      t.string :status_reason
      t.bigint :used_storage
      t.bigint :max_storage
      t.text   :extra_attributes

      t.belongs_to :ems, :type => :bigint
      t.belongs_to :resource_group, :type => :bigint
      t.belongs_to :cloud_database_flavor, :type => :bigint
      t.belongs_to :cloud_tenant, :type => :bigint
    end

    add_index :cloud_databases, :ems_id
    add_index :cloud_databases, :cloud_database_flavor_id
  end
end
