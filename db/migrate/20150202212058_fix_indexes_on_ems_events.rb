class FixIndexesOnEmsEvents < ActiveRecord::Migration
  def up
    if find_index_by_name(:ems_events, "index_ems_events_on_vm_id")
      rename_index :ems_events, "index_ems_events_on_vm_id",      "index_ems_events_on_vm_or_template_id"
    end
    if find_index_by_name(:ems_events, "index_ems_events_on_dest_vm_id")
      rename_index :ems_events, "index_ems_events_on_dest_vm_id", "index_ems_events_on_dest_vm_or_template_id"
    end
  end

  def down
    rename_index :ems_events, "index_ems_events_on_vm_or_template_id",      "index_ems_events_on_vm_id"
    rename_index :ems_events, "index_ems_events_on_dest_vm_or_template_id", "index_ems_events_on_dest_vm_id"
  end

  def find_index_by_name(table, name)
    indexes(table).find { |i| i.name == name }
  end
end
