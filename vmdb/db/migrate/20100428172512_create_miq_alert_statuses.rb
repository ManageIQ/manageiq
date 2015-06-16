class CreateMiqAlertStatuses < ActiveRecord::Migration
  def self.up
    create_table :miq_alert_statuses do |t|
      t.integer     :miq_alert_id
      t.integer     :resource_id
      t.string      :resource_type
      t.timestamp   :evaluated_on
    end
  end

  def self.down
    drop_table :miq_alert_statuses
  end
end
