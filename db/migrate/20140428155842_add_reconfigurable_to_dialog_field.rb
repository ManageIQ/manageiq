class AddReconfigurableToDialogField < ActiveRecord::Migration[4.2]
  def change
    add_column :dialog_fields, :reconfigurable, :boolean
  end
end
