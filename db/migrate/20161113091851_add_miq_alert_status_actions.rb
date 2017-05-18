class AddMiqAlertStatusActions < ActiveRecord::Migration[5.0]
  def change
    create_table :miq_alert_status_actions do |t|
      t.string     :action_type
      t.belongs_to :user,             :type => :bigint
      t.string     :comment
      t.belongs_to :assignee,         :type => :bigint
      t.belongs_to :miq_alert_status, :type => :bigint
      t.timestamps
    end
  end
end
