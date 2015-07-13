class RenameVmIdColumnsToVmOrTemplateId < ActiveRecord::Migration
  def change
    [:accounts, :ems_events, :guest_applications, :hardwares, :lifecycle_events, :operating_systems, :patches, :registry_items, :scan_histories, :snapshots, :storage_files, :system_services, :vdi_desktops].each do |table_name|
      rename_column table_name, :vm_id, :vm_or_template_id
    end
  end
end
