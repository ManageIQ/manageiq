class AddMiqAlertStatusState < ActiveRecord::Migration[5.0]
  def change
    create_table :miq_alert_status_states do |t|
      t.string     :action
      t.string     :comment
      t.belongs_to :user, :type => :bigint
      t.belongs_to :assignee, :type => :bigint
      t.belongs_to :miq_alert_status, :type => :bigint
      t.timestamps
    end
  end
end
