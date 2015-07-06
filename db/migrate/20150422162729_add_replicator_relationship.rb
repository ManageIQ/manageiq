class AddReplicatorRelationship < ActiveRecord::Migration
  def change
    add_column :container_groups, :container_replicator_id, :bigint
  end
end
