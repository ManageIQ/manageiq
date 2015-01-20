class FixStoragesVmsJoinTable < ActiveRecord::Migration
  def up
    # Temporarily remove the index.  Rails tries to rename the indexes for us,
    # but in this case, the name that Rails generates is too long, so we'll
    # remove it, then add it again after renaming
    remove_index :storages_vms, :name => 'index_storages_vms_on_vm_id_and_storage_id'
    rename_column :storages_vms, :vm_id, :vm_or_template_id
    rename_table  :storages_vms, :storages_vms_and_templates
    add_index :storages_vms_and_templates, [:vm_or_template_id, :storage_id], :unique => true,
      :name => 'index_storages_vms_on_vm_id_and_storage_id'
  end

  def down
    remove_index :storages_vms_and_templates, :name => 'index_storages_vms_on_vm_id_and_storage_id'
    rename_column :storages_vms_and_templates, :vm_or_template_id, :vm_id
    rename_table  :storages_vms_and_templates, :storages_vms
    add_index :storages_vms, [:vm_id, :storage_id], :unique => true,
      :name => 'index_storages_vms_on_vm_id_and_storage_id'
  end
end
