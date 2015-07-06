class AddIndexesToEmsEvents < ActiveRecord::Migration
  def self.up
    add_index    :ems_events, [:vm_id, :dest_vm_id]
    add_index    :ems_events, [:host_id, :dest_host_id]
    add_index    :ems_events, :ems_cluster_id
    add_index    :ems_events, :ems_id
  end

  def self.down
    remove_index :ems_events, [:vm_id, :dest_vm_id]
    remove_index :ems_events, [:host_id, :dest_host_id]
    remove_index :ems_events, :ems_cluster_id
    remove_index :ems_events, :ems_id
  end
end
