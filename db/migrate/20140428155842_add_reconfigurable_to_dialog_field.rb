class AddReconfigurableToDialogField < ActiveRecord::Migration
  def change
    add_column :dialog_fields, :reconfigurable, :boolean
  end
end
