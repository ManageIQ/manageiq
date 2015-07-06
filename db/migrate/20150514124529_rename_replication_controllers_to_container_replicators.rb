class RenameReplicationControllersToContainerReplicators < ActiveRecord::Migration
  def self.up
    rename_table :container_replication_controllers, :container_replicators
  end

  def self.down
    rename_table :container_replicators, :container_replication_controllers
  end
end
