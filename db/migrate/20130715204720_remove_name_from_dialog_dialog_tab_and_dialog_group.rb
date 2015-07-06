class RemoveNameFromDialogDialogTabAndDialogGroup < ActiveRecord::Migration
  def up
    remove_column :dialogs,       :name
    remove_column :dialog_tabs,   :name
    remove_column :dialog_groups, :name
  end

  def down
    add_column :dialogs,       :name, :string
    add_column :dialog_tabs,   :name, :string
    add_column :dialog_groups, :name, :string
  end
end