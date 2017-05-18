class RemoveAncestryFromAlerts < ActiveRecord::Migration[5.0]
  def change
    remove_index  :miq_alert_statuses, :ancestry
    remove_column :miq_alert_statuses, :ancestry, :string
  end
end
