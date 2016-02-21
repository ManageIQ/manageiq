class CreateCloudDatabases < ActiveRecord::Migration
  def change
    create_table :cloud_databases do |t|
      t.string :name
      t.string :type
      t.string :ems_ref
      t.string :db_engine
      t.string :status
      t.string :status_reason
      t.bigint :storage_size
      t.bigint :storage_quota
      t.text   :extra_attributes

      t.belongs_to :ems, :type => :bigint
      t.belongs_to :resource_group, :type => :bigint
      t.belongs_to :flavor, :type => :bigint
      t.belongs_to :cloud_tenant, :type => :bigint
    end

    add_index :cloud_databases, :ems_id
  end
end
