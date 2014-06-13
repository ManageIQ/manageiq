class FixStoragesVmsJoinTable < ActiveRecord::Migration
  def change
    rename_column :storages_vms, :vm_id, :vm_or_template_id
    rename_table  :storages_vms, :storages_vms_and_templates
  end
end
