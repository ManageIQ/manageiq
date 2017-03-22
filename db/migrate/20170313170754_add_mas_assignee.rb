class AddMasAssignee < ActiveRecord::Migration[5.0]
  def change
    add_reference :miq_alert_statuses, :assignee, :type => :bigint, :index => true
  end
end
