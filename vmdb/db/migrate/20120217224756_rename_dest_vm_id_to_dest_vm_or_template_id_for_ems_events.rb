class RenameDestVmIdToDestVmOrTemplateIdForEmsEvents < ActiveRecord::Migration
  def change
    rename_column :ems_events, :dest_vm_id, :dest_vm_or_template_id
  end
end
