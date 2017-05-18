class RenameReplicationControllersToContainerReplicators < ActiveRecord::Migration[4.2]
  def self.up
    rename_table :container_replication_controllers, :container_replicators
  end

  def self.down
    rename_table :container_replicators, :container_replication_controllers
  end
end
