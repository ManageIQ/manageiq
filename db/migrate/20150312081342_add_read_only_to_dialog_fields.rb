class AddReadOnlyToDialogFields < ActiveRecord::Migration[4.2]
  def change
    add_column :dialog_fields, :read_only, :boolean
  end
end
