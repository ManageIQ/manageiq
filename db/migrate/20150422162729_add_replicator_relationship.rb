class AddReplicatorRelationship < ActiveRecord::Migration[4.2]
  def change
    add_column :container_groups, :container_replicator_id, :bigint
  end
end
