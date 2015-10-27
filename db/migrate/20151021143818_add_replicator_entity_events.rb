class AddReplicatorEntityEvents < ActiveRecord::Migration
  def change
    add_column :event_streams, :container_replicator_id, :bigint
    add_column :event_streams, :container_replicator_name, :string
  end
end
