class AddAutoRefreshFieldsToDialogFields < ActiveRecord::Migration
  def change
    add_column :dialog_fields, :auto_refresh, :boolean
    add_column :dialog_fields, :trigger_auto_refresh, :boolean
  end
end
