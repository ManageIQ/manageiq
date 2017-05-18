class RenameContainerId < ActiveRecord::Migration[4.2]
  def change
    rename_column :containers, :container_id, :backing_ref
  end
end
