class AddEmsToMiqAlertStatus < ActiveRecord::Migration[5.0]
  def change
    add_column :miq_alert_statuses, :ems_id, :bigint
  end
end
