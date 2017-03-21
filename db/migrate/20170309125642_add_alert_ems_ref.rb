class AddAlertEmsRef < ActiveRecord::Migration[5.0]
  def change
    add_column :miq_alert_statuses, :event_ems_ref, :string
    add_index :miq_alert_statuses, :event_ems_ref
  end
end
