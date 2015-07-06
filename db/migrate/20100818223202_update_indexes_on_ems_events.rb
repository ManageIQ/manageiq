class UpdateIndexesOnEmsEvents < ActiveRecord::Migration
  def self.up
    remove_index :ems_events, [:vm_id, :dest_vm_id]
    remove_index :ems_events, [:host_id, :dest_host_id]

    add_index    :ems_events, :vm_id
    add_index    :ems_events, :dest_vm_id
    add_index    :ems_events, :host_id
    add_index    :ems_events, :dest_host_id
  end

  def self.down
    remove_index :ems_events, :vm_id
    remove_index :ems_events, :dest_vm_id
    remove_index :ems_events, :host_id
    remove_index :ems_events, :dest_host_id

    add_index    :ems_events, [:vm_id, :dest_vm_id]
    add_index    :ems_events, [:host_id, :dest_host_id]
  end
end
