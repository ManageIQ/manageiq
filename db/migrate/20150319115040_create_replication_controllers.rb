class CreateReplicationControllers < ActiveRecord::Migration
  def up
    create_table :container_replication_controllers do |t|
      t.string     :ems_ref
      t.string     :name
      t.timestamp  :creation_timestamp
      t.belongs_to :ems, :type => :bigint
      t.string     :resource_version
      t.string     :namespace
      t.integer    :replicas
      t.integer    :current_replicas
    end
  end

  def down
    drop_table :container_replication_controllers
  end
end
