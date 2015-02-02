class FixIndexesOnEmsEvents < ActiveRecord::Migration
  def up
    rename_index :ems_events, "index_ems_events_on_vm_id",      "index_ems_events_on_vm_or_template_id"
    rename_index :ems_events, "index_ems_events_on_dest_vm_id", "index_ems_events_on_dest_vm_or_template_id"
  end

  def down
    rename_index :ems_events, "index_ems_events_on_vm_or_template_id",      "index_ems_events_on_vm_id"
    rename_index :ems_events, "index_ems_events_on_dest_vm_or_template_id", "index_ems_events_on_dest_vm_id"
  end
end
