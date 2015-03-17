class AddReadOnlyToDialogFields < ActiveRecord::Migration
  def change
    add_column :dialog_fields, :read_only, :boolean
  end
end
