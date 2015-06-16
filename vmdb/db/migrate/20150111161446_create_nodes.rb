class CreateNodes < ActiveRecord::Migration
  def up
    create_table :container_nodes do |t|
      t.string    :ems_ref
      t.string    :name
      t.timestamp  :creation_timestamp
      t.string    :resource_version
      t.belongs_to :ems, :type => :bigint
    end
    add_index :container_nodes, :ems_id
  end

  def down
    remove_index :container_nodes, :ems_id
    drop_table :container_nodes
  end
end
