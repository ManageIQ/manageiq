class AddMissingFieldsToAlertStatus < ActiveRecord::Migration[5.0]
  def change
    add_column :miq_alert_statuses, :user_id, :bigint
    add_column :miq_alert_statuses, :asignee_ack_text, :text
  end
end
