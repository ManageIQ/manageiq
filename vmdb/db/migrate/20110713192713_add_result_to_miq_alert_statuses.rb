class AddResultToMiqAlertStatuses < ActiveRecord::Migration
  def self.up
    add_column      :miq_alert_statuses,  :result,  :boolean
  end

  def self.down
    remove_column   :miq_alert_statuses,  :result
  end
end
