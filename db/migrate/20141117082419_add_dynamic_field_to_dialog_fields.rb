class AddDynamicFieldToDialogFields < ActiveRecord::Migration[4.2]
  def up
    add_column :dialog_fields, :dynamic, :boolean
  end

  def down
    remove_column :dialog_fields, :dynamic
  end
end
