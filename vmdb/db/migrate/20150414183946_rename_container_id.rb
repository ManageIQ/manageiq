class RenameContainerId < ActiveRecord::Migration
  def change
    rename_column :containers, :container_id, :backing_ref
  end
end
