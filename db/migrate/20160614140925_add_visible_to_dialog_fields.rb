class AddVisibleToDialogFields < ActiveRecord::Migration[5.0]
  def change
    add_column :dialog_fields, :visible, :boolean, :default => true
  end
end
