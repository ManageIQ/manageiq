class AddHostServiceGroupToFilesystems < ActiveRecord::Migration[4.2]
  def change
    add_column :filesystems, :host_service_group_id, :bigint
    add_index :filesystems, :host_service_group_id
  end
end
