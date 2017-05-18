class AddMissingFieldsToAlertStatuses < ActiveRecord::Migration[5.0]
  def change
    add_column :miq_alert_statuses, :url,          :text
    add_column :miq_alert_statuses, :severity,     :string
    add_column :miq_alert_statuses, :ancestry,     :string
    add_column :miq_alert_statuses, :acknowledged, :boolean
    add_index  :miq_alert_statuses, :ancestry
  end
end
