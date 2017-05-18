class AddAutoRefreshFieldsToDialogFields < ActiveRecord::Migration[4.2]
  def change
    add_column :dialog_fields, :auto_refresh, :boolean
    add_column :dialog_fields, :trigger_auto_refresh, :boolean
  end
end
