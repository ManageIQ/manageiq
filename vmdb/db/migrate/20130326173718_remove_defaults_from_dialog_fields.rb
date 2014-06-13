class RemoveDefaultsFromDialogFields < ActiveRecord::Migration
  def up
    change_column_default('dialog_fields', :required, nil)
  end

  def down
    change_column_default('dialog_fields', :required, false)
  end
end
