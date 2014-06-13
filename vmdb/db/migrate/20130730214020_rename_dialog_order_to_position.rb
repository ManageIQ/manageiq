class RenameDialogOrderToPosition < ActiveRecord::Migration

  def change
    rename_column :dialog_tabs,   :order, :position
    rename_column :dialog_groups, :order, :position
    rename_column :dialog_fields, :order, :position
  end
end
