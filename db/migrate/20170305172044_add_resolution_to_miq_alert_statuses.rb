class AddResolutionToMiqAlertStatuses < ActiveRecord::Migration[5.0]
  def change
    add_column :miq_alert_statuses, :resolved, :boolean
  end
end
